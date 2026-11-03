// Reads the system's Now Playing state (any app: browsers, Spotify, Music, podcasts)
// and sends media commands, through the private MediaRemote framework.
//
// Since macOS 15.4, MediaRemote only answers Apple-signed processes, so Cleen does not
// call it directly: it runs /usr/bin/perl, which loads this library with DynaLoader and
// calls one of the functions below (see now-playing.pl). The approach comes from the
// open-source mediaremote-adapter project.
#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>

typedef void (*MRGetInfo)(dispatch_queue_t, void (^)(NSDictionary *));
typedef void (*MRGetPID)(dispatch_queue_t, void (^)(int));
typedef void (*MRGetPlaying)(dispatch_queue_t, void (^)(BOOL));
typedef void (*MRRegister)(dispatch_queue_t);
typedef Boolean (*MRSendCommand)(int, NSDictionary *);

/// A reading that hasn't answered after this long is given up on, so one lost
/// MediaRemote reply can't stop the stream for good.
static const CFAbsoluteTime ReadTimeout = 5;

// Main queue only: every MediaRemote reply, notification and the heartbeat land there.
static BOOL inFlight;
static BOOL dirty;
static unsigned long generation;
static CFAbsoluteTime startedAt;
static int lastPID = -1;
static NSString *lastArtworkKey;

static void Request(void);

static void *MediaRemote(void) {
    static void *handle;
    if (!handle) {
        handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW);
    }
    return handle;
}

static id Value(NSDictionary *info, NSString *key) {
    id value = info[key];
    return value ?: [NSNull null];
}

static void Write(NSDictionary *out) {
    NSData *json = [NSJSONSerialization dataWithJSONObject:out options:0 error:nil];
    if (!json) return;
    fwrite(json.bytes, 1, json.length, stdout);
    fputc('\n', stdout);
    // When Cleen goes away the pipe closes and this write ends the process.
    if (fflush(stdout) != 0) exit(0);
}

/// One line for the app `pid`, with `info` and `playing` both read for that same app.
static void Emit(int pid, NSDictionary *info, BOOL playing) {
    NSMutableDictionary *out = [NSMutableDictionary dictionary];
    out[@"pid"] = @(pid);
    out[@"playing"] = @(playing);
    // Another app took over: its artwork must go out even if the key happens to match,
    // because Cleen drops the previous app's artwork when the source changes.
    if (pid != lastPID) lastArtworkKey = nil;
    lastPID = pid;
    id title = info[@"kMRMediaRemoteNowPlayingInfoTitle"];
    if (![title isKindOfClass:[NSString class]] || [(NSString *)title length] == 0) {
        // Nothing playing: Cleen clears its artwork, so the next one is sent again.
        lastArtworkKey = nil;
        Write(out);
        return;
    }
    out[@"title"] = title;
    out[@"artist"] = Value(info, @"kMRMediaRemoteNowPlayingInfoArtist");
    out[@"album"] = Value(info, @"kMRMediaRemoteNowPlayingInfoAlbum");
    out[@"duration"] = Value(info, @"kMRMediaRemoteNowPlayingInfoDuration");
    out[@"elapsed"] = Value(info, @"kMRMediaRemoteNowPlayingInfoElapsedTime");
    out[@"rate"] = Value(info, @"kMRMediaRemoteNowPlayingInfoPlaybackRate");
    id timestamp = info[@"kMRMediaRemoteNowPlayingInfoTimestamp"];
    if ([timestamp isKindOfClass:[NSDate class]]) {
        out[@"timestamp"] = @([(NSDate *)timestamp timeIntervalSince1970]);
    }
    // Artwork only when it changed: it's the heavy part of every line.
    id artwork = info[@"kMRMediaRemoteNowPlayingInfoArtworkData"];
    if ([artwork isKindOfClass:[NSData class]]) {
        id artworkID = info[@"kMRMediaRemoteNowPlayingInfoArtworkIdentifier"];
        NSString *key = [artworkID isKindOfClass:[NSString class]]
            ? artworkID
            : [NSString stringWithFormat:@"%lu-%lu", (unsigned long)[(NSData *)artwork length], (unsigned long)[(NSData *)artwork hash]];
        out[@"artworkKey"] = key;
        if (![key isEqualToString:lastArtworkKey]) {
            out[@"artwork"] = [(NSData *)artwork base64EncodedStringWithOptions:0];
            lastArtworkKey = key;
        }
    } else {
        // Players drop the artwork from some updates (paused); forget the last one so
        // it is sent again when it comes back.
        lastArtworkKey = nil;
    }
    Write(out);
}

/// Reads the state and writes it. The three MediaRemote calls are asynchronous, so the
/// app can change between them; the PID is read before and after, and a reading that
/// straddles a change is thrown away and taken again, so a line never mixes one app's
/// info with another's PID or playing flag.
static void Read(void) {
    MRGetInfo getInfo = (MRGetInfo)dlsym(MediaRemote(), "MRMediaRemoteGetNowPlayingInfo");
    MRGetPID getPID = (MRGetPID)dlsym(MediaRemote(), "MRMediaRemoteGetNowPlayingApplicationPID");
    MRGetPlaying getPlaying = (MRGetPlaying)dlsym(MediaRemote(), "MRMediaRemoteGetNowPlayingApplicationIsPlaying");
    if (!getInfo || !getPID || !getPlaying) {
        inFlight = NO;
        return;
    }
    dispatch_queue_t queue = dispatch_get_main_queue();
    unsigned long reading = ++generation;
    getPID(queue, ^(int pid) {
        getInfo(queue, ^(NSDictionary *info) {
            getPlaying(queue, ^(BOOL playing) {
                getPID(queue, ^(int pidAfter) {
                    // Given up on (timed out); a newer reading owns the stream now.
                    if (reading != generation) return;
                    inFlight = NO;
                    if (pidAfter != pid) {
                        dirty = YES;
                    } else {
                        Emit(pid, info, playing);
                    }
                    if (dirty) Request();
                });
            });
        });
    });
}

/// Asks for a reading. One runs at a time; a change that arrives meanwhile is
/// coalesced into one more reading right after, so the last line is always current.
static void Request(void) {
    if (inFlight && CFAbsoluteTimeGetCurrent() - startedAt < ReadTimeout) {
        dirty = YES;
        return;
    }
    inFlight = YES;
    dirty = NO;
    startedAt = CFAbsoluteTimeGetCurrent();
    Read();
}

/// Streams a line on every change (and every few seconds as a heartbeat) until killed.
///
/// The change notifications carry the new app's PID and playing flag in their userInfo,
/// but they're only used as a signal: reading everything again from one consistent
/// snapshot is simpler than merging partial payloads, and costs a few milliseconds.
void cleen_stream(void) {
    MRRegister registerForNotifications = (MRRegister)dlsym(MediaRemote(), "MRMediaRemoteRegisterForNowPlayingNotifications");
    if (registerForNotifications) registerForNotifications(dispatch_get_main_queue());

    NSArray *names = @[
        @"kMRMediaRemoteNowPlayingInfoDidChangeNotification",
        @"kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification",
        @"kMRMediaRemoteNowPlayingApplicationDidChangeNotification",
    ];
    for (NSString *name in names) {
        [[NSNotificationCenter defaultCenter] addObserverForName:name object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
            Request();
        }];
    }

    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC, NSEC_PER_SEC / 2);
    dispatch_source_set_event_handler(timer, ^{ Request(); });
    dispatch_resume(timer);

    CFRunLoopRun();
}

/// Sends the command in $CLEEN_COMMAND (MediaRemote's numbering: 0 play, 1 pause,
/// 2 toggle, 4 next, 5 previous).
void cleen_send(void) {
    const char *raw = getenv("CLEEN_COMMAND");
    int command = raw ? atoi(raw) : 2;
    MRSendCommand send = (MRSendCommand)dlsym(MediaRemote(), "MRMediaRemoteSendCommand");
    if (send) send(command, nil);
    // The command travels over XPC; exiting right away can drop it.
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.4, false);
}
