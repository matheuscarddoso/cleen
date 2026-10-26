import CoreGraphics
import Foundation
import Testing
@testable import CleenKit

struct CursorTrackTests {
    private let track = CursorTrack(samples: [
        .init(t: 0, x: 0, y: 0),
        .init(t: 1, x: 1, y: 0.5),
        .init(t: 2, x: 1, y: 1),
    ])

    @Test func interpolatesBetweenSamples() throws {
        let middle = try #require(track.position(at: 0.5))
        #expect(abs(middle.x - 0.5) < 1e-9 && abs(middle.y - 0.25) < 1e-9)
        #expect(track.position(at: -1) == CGPoint(x: 0, y: 0))
        #expect(track.position(at: 9) == CGPoint(x: 1, y: 1))
        #expect(CursorTrack().position(at: 1) == nil)
    }

    @Test func smoothingLagsBehindAJumpAndSettles() throws {
        let jump = CursorTrack(samples: [.init(t: 0, x: 0, y: 0), .init(t: 0.01, x: 1, y: 1), .init(t: 3, x: 1, y: 1)])
        let path = CursorPath(track: jump, smoothing: 0.8)
        let early = try #require(path.position(at: 0.05))
        #expect(early.x < 0.5)
        let late = try #require(path.position(at: 2.9))
        #expect(abs(late.x - 1) < 0.01)
        // No overshoot: a critically damped spring never passes the target.
        for t in stride(from: 0.0, through: 3, by: 0.01) {
            #expect(try #require(path.position(at: t)).x <= 1.0001)
        }
    }

    @Test func noSmoothingIsTheRawPath() throws {
        let path = CursorPath(track: track, smoothing: 0)
        #expect(try #require(path.position(at: 1.5)) == track.position(at: 1.5))
    }
}

struct ZoomPlannerTests {
    private func click(_ t: Double) -> CursorTrack.Click { .init(t: t, x: 0.5, y: 0.5) }

    @Test func clicksCloseTogetherShareOneZoom() {
        let segments = ZoomPlanner.automatic(clicks: [click(2), click(3), click(4.5), click(12)], duration: 20)
        #expect(segments.count == 2)
        #expect(abs(segments[0].start - 1.4) < 1e-9 && abs(segments[0].end - 6.1) < 1e-9)
        #expect(abs(segments[1].start - 11.4) < 1e-9)
    }

    @Test func zoomsStayInsideTheRecording() {
        let segments = ZoomPlanner.automatic(clicks: [click(0.1), click(9.9)], duration: 10)
        #expect(segments.allSatisfy { $0.start >= 0 && $0.end <= 10 })
    }

    @Test func stateEasesInHoldsAndEasesOut() {
        let segment = ZoomSegment(start: 1, end: 3, scale: 2)
        let pointer: (Double) -> CGPoint? = { _ in CGPoint(x: 0.9, y: 0.9) }
        #expect(ZoomPlanner.state(at: 0.5, segments: [segment], pointer: pointer) == .none)
        let half = ZoomPlanner.state(at: 1 + ZoomPlanner.transition / 2, segments: [segment], pointer: pointer)
        #expect(half.scale > 1.4 && half.scale < 1.6)
        let full = ZoomPlanner.state(at: 2, segments: [segment], pointer: pointer)
        #expect(full.scale == 2)
        // The view can't slide past the edge: at 2× the center stops at 0.75.
        #expect(full.center == CGPoint(x: 0.75, y: 0.75))
        #expect(ZoomPlanner.state(at: 3 + ZoomPlanner.transition + 0.01, segments: [segment], pointer: pointer) == .none)
    }

    @Test func fixedFocusWinsOverThePointer() {
        let segment = ZoomSegment(start: 0, end: 5, scale: 2, focus: CGPoint(x: 0.3, y: 0.4))
        let state = ZoomPlanner.state(at: 2, segments: [segment], pointer: { _ in CGPoint(x: 0.9, y: 0.9) })
        #expect(state.center == CGPoint(x: 0.3, y: 0.4))
    }
}

struct FrameGeometryTests {
    @Test func canvasFollowsTheAspectInEvenPixels() {
        #expect(FrameGeometry.canvas(aspect: .wide, source: CGSize(width: 1512, height: 982), longSide: 1920) == CGSize(width: 1920, height: 1080))
        #expect(FrameGeometry.canvas(aspect: .vertical, source: .zero, longSide: 1920) == CGSize(width: 1080, height: 1920))
        let own = FrameGeometry.canvas(aspect: .source, source: CGSize(width: 1512, height: 982), longSide: 1920)
        #expect(own.width == 1920 && Int(own.height) % 2 == 0)
    }

    @Test func contentFitsInsideThePaddingCentered() {
        let canvas = CGSize(width: 1920, height: 1080)
        let rect = FrameGeometry.contentRect(canvas: canvas, source: CGSize(width: 1600, height: 1000), padding: 0.1)
        #expect(rect.minY >= 108 - 0.001 && rect.maxY <= 972 + 0.001)
        #expect(abs(rect.midX - 960) < 0.001 && abs(rect.midY - 540) < 0.001)
        #expect(abs(rect.width / rect.height - 1.6) < 0.001)
    }

    @Test func cameraSitsInItsCorner() {
        var camera = EditorStyle.Camera()
        camera.corner = .bottomRight
        let rect = FrameGeometry.cameraRect(canvas: CGSize(width: 1920, height: 1080), style: camera, aspect: 16.0 / 9, padding: 0.07)
        #expect(rect.width == rect.height)
        #expect(rect.maxX < 1920 && rect.maxY < 1080 && rect.minX > 960)
    }

    @Test func placingAPointFollowsTheZoom() {
        let content = CGRect(x: 100, y: 100, width: 1000, height: 500)
        #expect(FrameGeometry.place(CGPoint(x: 0.5, y: 0.5), zoom: .none, content: content) == CGPoint(x: 600, y: 350))
        let zoomed = ZoomState(scale: 2, center: CGPoint(x: 0.25, y: 0.25))
        // At 2× on the top-left quarter, that quarter's center is the content's center.
        #expect(FrameGeometry.place(CGPoint(x: 0.25, y: 0.25), zoom: zoomed, content: content) == CGPoint(x: 600, y: 350))
    }
}

struct RecordingProjectTests {
    @Test func roundTripsAndKeepsEdits() throws {
        let sandbox = try Sandbox()
        let folder = RecordingProject.newFolder(in: sandbox.root, date: Date(timeIntervalSince1970: 0), prefix: "Gravação")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var project = RecordingProject(source: .display, sourceSize: CGSize(width: 1512, height: 982), duration: 12.5, hasCamera: true)
        project.zoom = [ZoomSegment(start: 1, end: 3, scale: 2)]
        project.style.background = .color("#112233")
        project.trimStart = 0.5
        try project.save(to: folder)
        #expect(try RecordingProject.load(from: folder) == project)
        #expect(folder.pathExtension == "cleenrec")
        // A second recording in the same second gets its own folder.
        let next = RecordingProject.newFolder(in: sandbox.root, date: Date(timeIntervalSince1970: 0), prefix: "Gravação")
        #expect(next != folder)
    }
}

struct SquircleTests {
    /// Screen Studio's camera edge, measured off a 480 px capture: how far in the shape
    /// starts on each row from the top. (The very first rows are left out: there the
    /// capture's antialiasing decides more than the curve.)
    @Test func followsScreenStudiosCorner() {
        let path = Squircle.path(in: CGRect(x: 0, y: 0, width: 480, height: 480))
        let measured: [(Double, Double)] = [(4, 54), (8, 41), (16, 26), (24, 18), (32, 12), (48, 6), (64, 3), (96, 0)]
        for (row, inset) in measured {
            // The first x inside the path on this row.
            let first = (0..<480).first { path.contains(CGPoint(x: Double($0) + 0.5, y: row + 0.5)) } ?? 480
            #expect(abs(Double(first) - inset) <= 6, "row \(row): \(first) vs \(inset)")
        }
        // Straight edges between the corners.
        #expect(path.contains(CGPoint(x: 240, y: 0.5)))
        #expect(path.contains(CGPoint(x: 0.5, y: 240)))
    }
}
