import AppKit
import AVFoundation
import CleenKit
import CoreImage
import Observation
import os

/// One recording open in the editor: the project's edits, the player showing them, and
/// the export. Every edit is applied to the shared scene at once and the paused frame is
/// redrawn; the project is saved a moment after the last change, and can be undone.
@Observable
final class EditorModel {
    enum ExportState: Equatable {
        case idle
        case exporting(Double)
        case done(URL)
        case failed(String)
    }

    /// What's picked on the timeline; the inspector shows its settings.
    enum Selection: Equatable {
        case clip(ClipSegment.ID)
        case zoom(ZoomSegment.ID)
    }

    /// The inspector's pages, Screen Studio's right-hand icons.
    enum InspectorSection: String, CaseIterable {
        case background, cursor, camera, zoom, audio
    }

    /// The preview's sharpness, Screen Studio's Preview quality.
    enum PreviewQuality: String, CaseIterable {
        case full, half

        var longSide: Double { self == .full ? 1920 : 960 }
    }

    let folder: URL
    private(set) var project: RecordingProject
    /// Seconds of the finished video.
    private(set) var currentTime: Double = 0
    private(set) var isPlaying = false
    var selection: Selection?
    /// The scissors are out (the button): hovering the clips shows where a click would cut.
    var isCuttingLocked = false
    /// ⌥ is held: the scissors are out only while it is, as in Screen Studio.
    var isCuttingHeld = false
    var isCutting: Bool { isCuttingLocked || isCuttingHeld }
    /// The timeline's magnification: 1 fits the whole video.
    var timelineZoom = 1.0
    /// The inspector's page when nothing on the timeline is selected.
    var section = InspectorSection.background
    private(set) var exportState = ExportState.idle
    private(set) var previewQuality = PreviewQuality.full
    /// Cropping: the raw frame to draw the crop over.
    private(set) var cropFrame: CGImage?
    private(set) var canUndo = false
    private(set) var canRedo = false
    let player = AVPlayer()

    @ObservationIgnored private let track: CursorTrack
    @ObservationIgnored private let scene = EditorSceneBox()
    @ObservationIgnored private var sources: Sources?
    @ObservationIgnored private var composition: AVMutableComposition?
    @ObservationIgnored private var screenTrackID: CMPersistentTrackID = 1
    @ObservationIgnored private var cameraTrackID: CMPersistentTrackID?
    @ObservationIgnored private var audioTrackIDs: [CMPersistentTrackID] = []
    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var endObserver: (any NSObjectProtocol)?
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var cursorImage: (CIImage, CGPoint)?
    @ObservationIgnored private var backgroundImage: (key: EditorStyle.Background, image: CIImage?)?
    @ObservationIgnored private var undoStack: [RecordingProject] = []
    @ObservationIgnored private var redoStack: [RecordingProject] = []
    @ObservationIgnored private var lastUndoMark = Date.distantPast
    /// Export asked for before the timeline was ready: runs once it is.
    @ObservationIgnored private var exportsWhenReady = false
    private static let log = Logger(subsystem: "app.cleen.Cleen", category: "editor")

    /// The recording's tracks, loaded once; the timeline is rebuilt from them on every cut.
    private struct Sources {
        let screen: AVAssetTrack
        let audio: [AVAssetTrack]
        let camera: AVAssetTrack?
        let cameraDuration: CMTime
    }

    init?(folder: URL) {
        guard let project = try? RecordingProject.load(from: folder) else { return nil }
        self.folder = folder
        self.project = project
        track = RecordingProject.loadCursor(from: folder)
        // The pointer the Mac draws, at its real size; the renderer scales it.
        let arrow = NSCursor.arrow
        if let image = arrow.image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            let scale = CGFloat(image.width) / max(1, arrow.image.size.width)
            let ci = CIImage(cgImage: image).transformed(by: CGAffineTransform(scaleX: 1 / scale, y: 1 / scale))
            cursorImage = (ci, arrow.hotSpot)
        }
        updateScene()
        load()
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 30), queue: .main) { [weak self] time in
            MainActor.assumeIsolated { self?.tick(time) }
        }
        endObserver = NotificationCenter.default.addObserver(forName: AVPlayerItem.didPlayToEndTimeNotification, object: nil, queue: .main) { [weak self] note in
            let item = ObjectIdentifier(note.object as AnyObject)
            MainActor.assumeIsolated {
                guard let self, let current = self.player.currentItem, ObjectIdentifier(current) == item else { return }
                self.isPlaying = false
                self.currentTime = self.duration
            }
        }
    }

    var name: String { folder.deletingPathExtension().lastPathComponent }

    var style: EditorStyle { project.style }

    var timeline: EditTimeline { project.timeline }

    /// The finished video's length.
    var duration: Double { max(0.1, timeline.duration) }

    // MARK: Composition

    private func load() {
        let screenAsset = AVURLAsset(url: folder.appending(path: RecordingProject.screenName))
        let cameraAsset = project.hasCamera ? AVURLAsset(url: folder.appending(path: RecordingProject.cameraName)) : nil
        Task {
            do {
                guard let screen = try await screenAsset.loadTracks(withMediaType: .video).first else { throw EditorError.unreadable }
                let audio = try await screenAsset.loadTracks(withMediaType: .audio)
                var camera: AVAssetTrack?
                var cameraDuration = CMTime.zero
                if let cameraAsset {
                    camera = try await cameraAsset.loadTracks(withMediaType: .video).first
                    cameraDuration = try await cameraAsset.load(.duration)
                }
                sources = Sources(screen: screen, audio: audio, camera: camera, cameraDuration: cameraDuration)
                rebuild()
                if exportsWhenReady { exportMovie() }
            } catch {
                Self.log.error("editor load failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// The clips one after the other, each at its speed, on one composition the
    /// compositor draws; the player gets it fresh, at the same moment.
    private func rebuild() {
        guard let sources else { return }
        let composition = AVMutableComposition()
        guard let screenTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else { return }
        let audioTracks = sources.audio.compactMap { _ in composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) }
        let cameraTrack = sources.camera.flatMap { _ in composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) }
        var at = CMTime.zero
        for clip in project.clips {
            let range = CMTimeRange(start: CMTime(seconds: clip.start, preferredTimescale: 600), end: CMTime(seconds: clip.end, preferredTimescale: 600))
            do {
                try screenTrack.insertTimeRange(range, of: sources.screen, at: at)
                for (source, target) in zip(sources.audio, audioTracks) {
                    try target.insertTimeRange(range, of: source, at: at)
                }
                if let camera = sources.camera, let cameraTrack {
                    let cameraRange = range.intersection(CMTimeRange(start: .zero, duration: sources.cameraDuration))
                    if cameraRange.duration > .zero { try cameraTrack.insertTimeRange(cameraRange, of: camera, at: at + (cameraRange.start - range.start)) }
                }
            } catch {
                Self.log.error("clip insert failed: \(error.localizedDescription, privacy: .public)")
                continue
            }
            if abs(clip.speed - 1) > 0.001 {
                composition.scaleTimeRange(CMTimeRange(start: at, duration: range.duration), toDuration: CMTimeMultiplyByFloat64(range.duration, multiplier: 1 / clip.speed))
            }
            at = composition.duration
        }
        screenTrackID = screenTrack.trackID
        audioTrackIDs = audioTracks.map(\.trackID)
        cameraTrackID = cameraTrack?.trackID
        self.composition = composition
        let item = AVPlayerItem(asset: composition)
        item.audioTimePitchAlgorithm = .spectral
        item.videoComposition = videoComposition(longSide: previewQuality.longSide)
        item.audioMix = audioMix()
        player.replaceCurrentItem(with: item)
        seek(to: min(currentTime, duration))
    }

    enum EditorError: LocalizedError {
        case unreadable
        var errorDescription: String? { String(localized: "Não deu para abrir a gravação.") }
    }

    func videoComposition(longSide: Double) -> AVVideoComposition? {
        guard let composition else { return nil }
        let canvas = canvasSize(longSide: longSide)
        let range = CMTimeRange(start: .zero, duration: composition.duration)
        let instruction = EditorInstruction(timeRange: range, screenTrack: screenTrackID, cameraTrack: cameraTrackID, scene: scene)
        var configuration = AVVideoComposition.Configuration()
        configuration.customVideoCompositorClass = EditorCompositor.self
        configuration.instructions = [instruction]
        configuration.renderSize = canvas
        configuration.frameDuration = CMTime(value: 1, timescale: CMTimeScale(project.export.framesPerSecond))
        return AVVideoComposition(configuration: configuration)
    }

    func canvasSize(longSide: Double) -> CGSize {
        FrameGeometry.canvas(aspect: project.style.aspect, source: project.croppedSize, longSide: longSide)
    }

    private func audioMix() -> AVAudioMix {
        let mix = AVMutableAudioMix()
        mix.inputParameters = zip(audioTrackIDs, project.audio).map { id, source in
            let parameters = AVMutableAudioMixInputParameters()
            parameters.trackID = id
            parameters.audioTimePitchAlgorithm = .spectral
            let muted = source == .system ? project.style.mutesSystemAudio : project.style.mutesMicrophone
            parameters.setVolume(muted ? 0 : 1, at: .zero)
            return parameters
        }
        return mix
    }

    // MARK: Edits

    /// Changes the project and redraws. Changes close together (a slider's drag, a
    /// block's slide) undo as one.
    func edit(_ change: (inout RecordingProject) -> Void) {
        let before = project
        change(&project)
        guard project != before else { return }
        if Date.now.timeIntervalSince(lastUndoMark) > 0.6 {
            undoStack.append(before)
            if undoStack.count > 200 { undoStack.removeFirst() }
            redoStack.removeAll()
        }
        lastUndoMark = .now
        if project.style.autoZoom != before.style.autoZoom {
            project.zoom = project.style.autoZoom ? ZoomPlanner.automatic(clicks: track.clicks, duration: project.duration, scale: project.style.zoomScale) : []
        }
        applied(from: before)
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        let before = project
        redoStack.append(project)
        project = previous
        lastUndoMark = .distantPast
        applied(from: before)
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        let before = project
        undoStack.append(project)
        project = next
        lastUndoMark = .distantPast
        applied(from: before)
    }

    /// Brings the scene, the player and the selection in line with `project`.
    private func applied(from before: RecordingProject) {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
        if case .clip(let id) = selection, !project.clips.contains(where: { $0.id == id }) { selection = nil }
        if case .zoom(let id) = selection, !project.zoom.contains(where: { $0.id == id }) { selection = nil }
        updateScene()
        if project.clips != before.clips {
            rebuild()
        } else {
            if project.style.aspect != before.style.aspect || project.crop != before.crop || project.export.framesPerSecond != before.export.framesPerSecond {
                player.currentItem?.videoComposition = videoComposition(longSide: previewQuality.longSide)
            }
            if project.style.mutesMicrophone != before.style.mutesMicrophone || project.style.mutesSystemAudio != before.style.mutesSystemAudio {
                player.currentItem?.audioMix = audioMix()
            }
            redraw()
        }
        scheduleSave()
    }

    private func updateScene() {
        scene.scene = EditorScene(
            style: project.style,
            zoom: project.zoom,
            sourceSize: project.sourceSize,
            crop: project.crop,
            timeline: project.timeline,
            hasCamera: project.hasCamera,
            cursor: CursorPath(track: track, smoothing: project.style.cursorSmoothing),
            zoomFocus: CursorPath(track: track, smoothing: 0.97),
            clicks: track.clicks,
            cursorImage: cursorImage?.0,
            cursorHotSpot: cursorImage?.1 ?? .zero,
            backgroundImage: picture(for: project.style.background)
        )
    }

    /// The background's picture, read once per choice.
    private func picture(for background: EditorStyle.Background) -> CIImage? {
        if let backgroundImage, backgroundImage.key == background { return backgroundImage.image }
        let image: CIImage? = switch background {
        case .wallpaper:
            (NSScreen.main.flatMap { NSWorkspace.shared.desktopImageURL(for: $0) }).flatMap { CIImage(contentsOf: $0) }
        case .picture(let path):
            CIImage(contentsOf: URL(filePath: path))
        default:
            nil
        }
        backgroundImage = (background, image)
        return image
    }

    /// A paused player draws again only when asked: a seek to the same frame does it.
    private func redraw() {
        guard !isPlaying else { return }
        player.currentItem?.videoComposition = player.currentItem?.videoComposition?.mutableCopy() as? AVVideoComposition
        player.seek(to: CMTime(seconds: currentTime, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func setPreviewQuality(_ quality: PreviewQuality) {
        previewQuality = quality
        player.currentItem?.videoComposition = videoComposition(longSide: quality.longSide)
        redraw()
    }

    // MARK: Clips

    /// Cuts the clip under `time` (the finished video's) in two.
    func split(at time: Double) {
        let clips = timeline.splitting(at: time)
        guard clips != project.clips else { return }
        edit { $0.clips = clips }
        if let index = timeline.clipIndex(at: time + 0.001) { selection = .clip(project.clips[index].id) }
    }

    func removeClip(_ id: ClipSegment.ID) {
        guard project.clips.count > 1 else { return }
        edit { $0.clips.removeAll { $0.id == id } }
    }

    func setSpeed(_ speed: Double, for id: ClipSegment.ID) {
        edit { project in
            guard let index = project.clips.firstIndex(where: { $0.id == id }) else { return }
            project.clips[index].speed = speed
        }
    }

    func setSpeedForAll(_ speed: Double) {
        edit { project in
            for index in project.clips.indices { project.clips[index].speed = speed }
        }
    }

    /// Moves one end of a clip to the recording's second `source`, never over its
    /// neighbors and never shorter than a fifth of a second.
    func trim(_ id: ClipSegment.ID, leading: Bool, to source: Double) {
        edit { project in
            guard let index = project.clips.firstIndex(where: { $0.id == id }) else { return }
            let clip = project.clips[index]
            if leading {
                let floor = index > 0 ? project.clips[index - 1].end : 0
                project.clips[index].start = min(clip.end - 0.2, max(floor, source))
            } else {
                let ceiling = index < project.clips.count - 1 ? project.clips[index + 1].start : project.duration
                project.clips[index].end = max(clip.start + 0.2, min(ceiling, source))
            }
        }
    }

    // MARK: Zoom segments

    func addZoom() {
        let start = timeline.sourceTime(at: currentTime)
        let segment = ZoomSegment(start: start, end: min(project.duration, start + 2.5), scale: project.style.zoomScale)
        edit { $0.zoom = ($0.zoom + [segment]).sorted { $0.start < $1.start } }
        selection = .zoom(segment.id)
    }

    func updateZoom(_ id: ZoomSegment.ID, _ change: (inout ZoomSegment) -> Void) {
        edit { project in
            guard let index = project.zoom.firstIndex(where: { $0.id == id }) else { return }
            change(&project.zoom[index])
            project.zoom[index].start = max(0, min(project.zoom[index].start, project.duration - 0.3))
            project.zoom[index].end = max(project.zoom[index].start + 0.3, min(project.zoom[index].end, project.duration))
        }
    }

    func removeZoom(_ id: ZoomSegment.ID) {
        edit { $0.zoom.removeAll { $0.id == id } }
    }

    /// Delete: whatever is selected goes.
    func removeSelection() {
        switch selection {
        case .clip(let id): removeClip(id)
        case .zoom(let id): removeZoom(id)
        case nil: break
        }
    }

    // MARK: Crop

    func beginCrop() {
        pause()
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: folder.appending(path: RecordingProject.screenName)))
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let time = CMTime(seconds: timeline.sourceTime(at: currentTime), preferredTimescale: 600)
        Task {
            cropFrame = try? await generator.image(at: time).image
        }
    }

    func endCrop(_ rect: CGRect?) {
        cropFrame = nil
        guard let rect else { return }
        // Nearly all of it is all of it.
        let whole = rect.width > 0.995 && rect.height > 0.995
        edit { $0.crop = whole ? nil : rect }
    }

    // MARK: Playback

    func togglePlay() {
        if isPlaying {
            pause()
        } else {
            if currentTime >= duration - 0.05 { seek(to: 0) }
            player.play()
            isPlaying = true
        }
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    func seek(to seconds: Double) {
        let clamped = max(0, min(duration, seconds))
        currentTime = clamped
        player.seek(to: CMTime(seconds: clamped, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    /// One frame back or forward (`frames` negative goes back).
    func step(frames: Int) {
        pause()
        seek(to: currentTime + Double(frames) / Double(project.export.framesPerSecond))
    }

    /// The previous clip's start (or this one's, when past it).
    func seekBackward() {
        let starts = timeline.starts
        seek(to: starts.last { $0 < currentTime - 0.05 } ?? 0)
    }

    func seekForward() {
        let ends = timeline.starts.dropFirst() + [duration]
        seek(to: ends.first { $0 > currentTime + 0.05 } ?? duration)
    }

    private func tick(_ time: CMTime) {
        let seconds = time.seconds
        guard seconds.isFinite, isPlaying else { return }
        currentTime = seconds
    }

    // MARK: Export

    /// Writes the finished movie to Filmes › Cleen, as MP4.
    func exportMovie() {
        guard let composition else {
            exportsWhenReady = true
            return
        }
        exportsWhenReady = false
        if case .exporting = exportState { return }
        save()
        try? FileManager.default.createDirectory(at: RecorderModel.folder, withIntermediateDirectories: true)
        let url = Self.uniqueURL(RecorderModel.folder.appending(path: "\(name).mp4"))
        guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHEVCHighestQuality) else {
            exportState = .failed(String(localized: "Não deu para exportar."))
            return
        }
        session.videoComposition = videoComposition(longSide: project.export.resolution.longSide)
        session.audioMix = audioMix()
        session.audioTimePitchAlgorithm = .spectral
        exportState = .exporting(0)
        Task {
            let progress = Task {
                for await state in session.states(updateInterval: 0.2) {
                    if case .exporting(let progress) = state { self.exportState = .exporting(progress.fractionCompleted) }
                }
            }
            do {
                try await session.export(to: url, as: .mp4)
                progress.cancel()
                exportState = .done(url)
            } catch {
                progress.cancel()
                Self.log.error("export failed: \(error.localizedDescription, privacy: .public)")
                exportState = .failed(error.localizedDescription)
            }
        }
    }

    func dismissExport() {
        exportState = .idle
    }

    private static func uniqueURL(_ url: URL) -> URL {
        let folder = url.deletingLastPathComponent()
        let base = url.deletingPathExtension().lastPathComponent
        var candidate = url
        var n = 2
        while FileManager.default.fileExists(atPath: candidate.path(percentEncoded: false)) {
            candidate = folder.appending(path: "\(base) \(n).\(url.pathExtension)")
            n += 1
        }
        return candidate
    }

    // MARK: Files

    func revealInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([folder])
    }

    /// Moves the recording to the Trash (it can come back from there).
    func moveToTrash() -> Bool {
        pause()
        saveTask?.cancel()
        do {
            try FileManager.default.trashItem(at: folder, resultingItemURL: nil)
            return true
        } catch {
            Self.log.error("trash failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    // MARK: Saving

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            save()
        }
    }

    func save() {
        saveTask?.cancel()
        guard FileManager.default.fileExists(atPath: folder.path(percentEncoded: false)) else { return }
        do {
            try project.save(to: folder)
        } catch {
            Self.log.error("save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func close() {
        player.pause()
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        timeObserver = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
        save()
    }
}
