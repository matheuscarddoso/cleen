import AppKit
import AVFoundation
import CleenKit
import CoreImage
import Observation
import os

/// One recording open in the editor: the project's edits, the player showing them, and
/// the export. Every edit is applied to the shared scene at once and the paused frame is
/// redrawn; the project is saved a moment after the last change.
@Observable
final class EditorModel {
    enum ExportState: Equatable {
        case idle
        case exporting(Double)
        case done(URL)
        case failed(String)
    }

    let folder: URL
    private(set) var project: RecordingProject
    private(set) var currentTime: Double = 0
    private(set) var isPlaying = false
    var selectedZoom: ZoomSegment.ID?
    private(set) var exportState = ExportState.idle
    let player = AVPlayer()

    @ObservationIgnored private let track: CursorTrack
    @ObservationIgnored private let scene = EditorSceneBox()
    @ObservationIgnored private var composition: AVMutableComposition?
    @ObservationIgnored private var screenTrackID: CMPersistentTrackID = 1
    @ObservationIgnored private var cameraTrackID: CMPersistentTrackID?
    @ObservationIgnored private var audioTrackIDs: [CMPersistentTrackID] = []
    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var cursorImage: (CIImage, CGPoint)?
    @ObservationIgnored private var wallpaper: CIImage?
    /// Export asked for before the timeline was ready: runs once it is.
    @ObservationIgnored private var exportsWhenReady = false
    private static let log = Logger(subsystem: "app.cleen.Cleen", category: "editor")

    init?(folder: URL) {
        guard let project = try? RecordingProject.load(from: folder) else { return nil }
        self.folder = folder
        self.project = project
        track = RecordingProject.loadCursor(from: folder)
        currentTime = project.trimStart
        // The pointer the Mac draws, at its real size; the renderer scales it.
        let arrow = NSCursor.arrow
        if let image = arrow.image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            let scale = CGFloat(image.width) / max(1, arrow.image.size.width)
            let ci = CIImage(cgImage: image).transformed(by: CGAffineTransform(scaleX: 1 / scale, y: 1 / scale))
            cursorImage = (ci, arrow.hotSpot)
        }
        if let screen = NSScreen.main, let url = NSWorkspace.shared.desktopImageURL(for: screen) {
            wallpaper = CIImage(contentsOf: url)
        }
        updateScene()
        build()
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 30), queue: .main) { [weak self] time in
            MainActor.assumeIsolated { self?.tick(time) }
        }
    }

    var name: String { folder.deletingPathExtension().lastPathComponent }

    var style: EditorStyle { project.style }

    // MARK: Composition

    /// The screen, the camera and the sound tracks on one timeline, drawn by the
    /// editor's compositor.
    private func build() {
        let screenAsset = AVURLAsset(url: folder.appending(path: RecordingProject.screenName))
        let cameraAsset = project.hasCamera ? AVURLAsset(url: folder.appending(path: RecordingProject.cameraName)) : nil
        Task {
            do {
                let composition = AVMutableComposition()
                let duration = try await screenAsset.load(.duration)
                let range = CMTimeRange(start: .zero, duration: duration)
                guard let screenVideo = try await screenAsset.loadTracks(withMediaType: .video).first,
                      let screenTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
                else { throw EditorError.unreadable }
                try screenTrack.insertTimeRange(range, of: screenVideo, at: .zero)
                screenTrackID = screenTrack.trackID
                audioTrackIDs = []
                for audio in try await screenAsset.loadTracks(withMediaType: .audio) {
                    guard let track = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else { continue }
                    try track.insertTimeRange(range, of: audio, at: .zero)
                    audioTrackIDs.append(track.trackID)
                }
                if let cameraAsset, let cameraVideo = try await cameraAsset.loadTracks(withMediaType: .video).first,
                   let cameraTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) {
                    let cameraDuration = try await cameraAsset.load(.duration)
                    try cameraTrack.insertTimeRange(CMTimeRange(start: .zero, duration: CMTimeMinimum(cameraDuration, duration)), of: cameraVideo, at: .zero)
                    cameraTrackID = cameraTrack.trackID
                }
                self.composition = composition
                let item = AVPlayerItem(asset: composition)
                item.videoComposition = videoComposition(longSide: 1280)
                item.audioMix = audioMix()
                player.replaceCurrentItem(with: item)
                applyTrim()
                if exportsWhenReady { exportMovie() }
            } catch {
                Self.log.error("editor build failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    enum EditorError: LocalizedError {
        case unreadable
        var errorDescription: String? { String(localized: "Não deu para abrir a gravação.") }
    }

    func videoComposition(longSide: Double) -> AVVideoComposition? {
        guard let composition else { return nil }
        let canvas = FrameGeometry.canvas(aspect: project.style.aspect, source: project.sourceSize, longSide: longSide)
        let range = CMTimeRange(start: .zero, duration: composition.duration)
        let instruction = EditorInstruction(timeRange: range, screenTrack: screenTrackID, cameraTrack: cameraTrackID, scene: scene, offset: 0)
        var configuration = AVVideoComposition.Configuration()
        configuration.customVideoCompositorClass = EditorCompositor.self
        configuration.instructions = [instruction]
        configuration.renderSize = canvas
        configuration.frameDuration = CMTime(value: 1, timescale: CMTimeScale(project.export.framesPerSecond))
        return AVVideoComposition(configuration: configuration)
    }

    private func audioMix() -> AVAudioMix {
        let mix = AVMutableAudioMix()
        mix.inputParameters = zip(audioTrackIDs, project.audio).map { id, source in
            let parameters = AVMutableAudioMixInputParameters()
            parameters.trackID = id
            let muted = source == .system ? project.style.mutesSystemAudio : project.style.mutesMicrophone
            parameters.setVolume(muted ? 0 : 1, at: .zero)
            return parameters
        }
        return mix
    }

    // MARK: Edits

    /// Changes the style (or anything else in the project) and redraws.
    func edit(_ change: (inout RecordingProject) -> Void) {
        let before = project
        change(&project)
        guard project != before else { return }
        if project.style.autoZoom != before.style.autoZoom {
            project.zoom = project.style.autoZoom ? ZoomPlanner.automatic(clicks: track.clicks, duration: project.duration, scale: project.style.zoomScale) : []
        }
        updateScene()
        if project.style.aspect != before.style.aspect {
            player.currentItem?.videoComposition = videoComposition(longSide: 1280)
        }
        if project.style.mutesMicrophone != before.style.mutesMicrophone || project.style.mutesSystemAudio != before.style.mutesSystemAudio {
            player.currentItem?.audioMix = audioMix()
        }
        if project.trimStart != before.trimStart || project.trimEnd != before.trimEnd { applyTrim() }
        redraw()
        scheduleSave()
    }

    private func updateScene() {
        scene.scene = EditorScene(
            style: project.style,
            zoom: project.zoom,
            sourceSize: project.sourceSize,
            hasCamera: project.hasCamera,
            cursor: CursorPath(track: track, smoothing: project.style.cursorSmoothing),
            zoomFocus: CursorPath(track: track, smoothing: 0.97),
            clicks: track.clicks,
            cursorImage: cursorImage?.0,
            cursorHotSpot: cursorImage?.1 ?? .zero,
            wallpaper: wallpaper
        )
    }

    /// A paused player draws again only when asked: a seek to the same frame does it.
    private func redraw() {
        guard !isPlaying else { return }
        player.currentItem?.videoComposition = player.currentItem?.videoComposition?.mutableCopy() as? AVVideoComposition
        player.seek(to: CMTime(seconds: currentTime, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    // MARK: Zoom segments

    func addZoom() {
        let start = currentTime
        let segment = ZoomSegment(start: start, end: min(project.duration, start + 2.5), scale: project.style.zoomScale)
        edit { $0.zoom = ($0.zoom + [segment]).sorted { $0.start < $1.start } }
        selectedZoom = segment.id
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
        if selectedZoom == id { selectedZoom = nil }
    }

    // MARK: Playback

    func togglePlay() {
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            if currentTime >= project.trimEnd - 0.05 { seek(to: project.trimStart) }
            player.play()
            isPlaying = true
        }
    }

    func seek(to seconds: Double) {
        let clamped = max(0, min(project.duration, seconds))
        currentTime = clamped
        player.seek(to: CMTime(seconds: clamped, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func applyTrim() {
        player.currentItem?.forwardPlaybackEndTime = CMTime(seconds: project.trimEnd, preferredTimescale: 600)
        if currentTime < project.trimStart || currentTime > project.trimEnd { seek(to: project.trimStart) }
    }

    private func tick(_ time: CMTime) {
        let seconds = time.seconds
        guard seconds.isFinite else { return }
        currentTime = seconds
        if isPlaying, seconds >= project.trimEnd - 0.02 {
            player.pause()
            isPlaying = false
        }
    }

    // MARK: Export

    /// Writes the trimmed, styled movie next to the recording, as MP4.
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
        session.timeRange = CMTimeRange(start: CMTime(seconds: project.trimStart, preferredTimescale: 600), end: CMTime(seconds: project.trimEnd, preferredTimescale: 600))
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
        save()
    }
}
