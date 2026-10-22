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

/// Writes one JSON line with the current state to stdout.
static void Emit(void) {
    dispatch_queue_t queue = dispatch_get_main_queue();
    MRGetInfo getInfo = (MRGetInfo)dlsym(MediaRemote(), "MRMediaRemoteGetNowPlayingInfo");
    MRGetPID getPID = (MRGetPID)dlsym(MediaRemote(), "MRMediaRemoteGetNowPlayingApplicationPID");
    MRGetPlaying getPlaying = (MRGetPlaying)dlsym(MediaRemote(), "MRMediaRemoteGetNowPlayingApplicationIsPlaying");
    if (!getInfo || !getPID || !getPlaying) return;

    getInfo(queue, ^(NSDictionary *info) {
        getPID(queue, ^(int pid) {
            getPlaying(queue, ^(BOOL playing) {
                NSMutableDictionary *out = [NSMutableDictionary dictionary];
                out[@"pid"] = @(pid);
                out[@"playing"] = @(playing);
                if (info) {
                    out[@"title"] = Value(info, @"kMRMediaRemoteNowPlayingInfoTitle");
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
                    static NSString *lastArtworkKey;
                    id artwork = info[@"kMRMediaRemoteNowPlayingInfoArtworkData"];
                    // Players drop the artwork from some updates (paused); forget the
                    // last one so it is sent again when it comes back.
                    if (![artwork isKindOfClass:[NSData class]]) lastArtworkKey = nil;
                    id artworkID = info[@"kMRMediaRemoteNowPlayingInfoArtworkIdentifier"];
                    if ([artwork isKindOfClass:[NSData class]]) {
                        NSString *key = [artworkID isKindOfClass:[NSString class]]
                            ? artworkID
                            : [NSString stringWithFormat:@"%lu-%lu", (unsigned long)[(NSData *)artwork length], (unsigned long)[(NSData *)artwork hash]];
                        out[@"artworkKey"] = key;
                        if (![key isEqualToString:lastArtworkKey]) {
                            out[@"artwork"] = [(NSData *)artwork base64EncodedStringWithOptions:0];
                            lastArtworkKey = key;
                        }
                    }
                }
                NSData *json = [NSJSONSerialization dataWithJSONObject:out options:0 error:nil];
                if (!json) return;
                fwrite(json.bytes, 1, json.length, stdout);
                fputc('\n', stdout);
                // When Cleen goes away the pipe closes and this write ends the process.
                if (fflush(stdout) != 0) exit(0);
            });
        });
    });
}

/// Streams a line on every change (and every few seconds as a heartbeat) until killed.
void cleen_stream(void) {
    MRRegister registerForNotifications = (MRRegister)dlsym(MediaRemote(), "MRMediaRemoteRegisterForNowPlayingNotifications");
    if (registerForNotifications) registerForNotifications(dispatch_get_main_queue());

    NSArray *names = @[
        @"kMRMediaRemoteNowPlayingInfoDidChangeNotification",
        @"kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification",
        @"kMRMediaRemoteNowPlayingApplicationDidChangeNotification",
    ];
    for (NSString *name in names) {
        [[NSNotificationCenter defaultCenter] addObserverForName:name object:nil queue:nil usingBlock:^(NSNotification *note) {
            Emit();
        }];
    }

    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC, NSEC_PER_SEC / 2);
    dispatch_source_set_event_handler(timer, ^{ Emit(); });
    dispatch_resume(timer);

    CFRunLoopRun();
}

/// Sends the command in $CLEEN_COMMAND (MediaRemote's numbering: 2 toggle, 4 next, 5 previous).
void cleen_send(void) {
    const char *raw = getenv("CLEEN_COMMAND");
    int command = raw ? atoi(raw) : 2;
    MRSendCommand send = (MRSendCommand)dlsym(MediaRemote(), "MRMediaRemoteSendCommand");
    if (send) send(command, nil);
    // The command travels over XPC; exiting right away can drop it.
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.4, false);
}
