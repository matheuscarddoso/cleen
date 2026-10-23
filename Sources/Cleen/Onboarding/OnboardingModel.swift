import AppKit
import ApplicationServices
import CleenKit
import Observation
import ServiceManagement
import SwiftUI
import UserNotifications

/// The first-run tour: where it is, what the person has granted so far, and the beats
/// of the opening titles. The page is saved as it changes, so a relaunch (Full Disk
/// Access sometimes asks for one) picks up where the person left off.
@Observable
final class OnboardingModel {
    enum Phase: Equatable {
        /// A notch-sized black shape at the top of the screen, about to open.
        case arriving
        /// The opening titles over the painting.
        case titles
        /// The pages.
        case tour
        /// Folding back into the notch.
        case leaving
    }

    /// The opening titles, in order.
    enum TitleBeat: Int, Comparable {
        case dark
        case painting
        case credit
        case wordmark
        case settle

        static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
    }

    private static let completedKey = "onboardingCompleted"
    private static let stepKey = "onboardingStep"

    /// Shown on the first launch, and on `--onboarding`.
    static var isNeeded: Bool {
        LaunchArguments.onboarding || !UserDefaults.standard.bool(forKey: completedKey)
    }

    private(set) var phase = Phase.arriving
    private(set) var beat = TitleBeat.dark
    private(set) var step: OnboardingStep
    /// Set when moving back, so pages slide the other way.
    private(set) var movingBack = false

    private(set) var fullDiskAccess = FullDiskAccess.isGranted
    private(set) var accessibility = AXIsProcessTrusted()
    private(set) var notifications = false
    /// Set when the person tries the shortcut on its page.
    private(set) var triedShortcut = false
    /// The modifier keys held right now, so the keycaps on the shortcut page press down.
    var heldModifiers: NSEvent.ModifierFlags = []
    /// Flips on each press of the shortcut, for the C keycap.
    private(set) var shortcutPresses = 0
    /// The free space line on the disk page, read once.
    let freeSpace: Int64?

    let sound = OnboardingSound()
    /// Called once the panel has folded back into the notch.
    @ObservationIgnored var onFinish: () -> Void = {}
    @ObservationIgnored private var titles: Task<Void, Never>?
    @ObservationIgnored private var poller: Task<Void, Never>?

    init() {
        let saved = UserDefaults.standard.integer(forKey: Self.stepKey)
        step = LaunchArguments.onboarding ? .welcome : OnboardingStep(rawValue: saved) ?? .welcome
        freeSpace = (try? URL.homeDirectory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]))?.volumeAvailableCapacityForImportantUsage
    }

    var isMuted: Bool {
        get { sound.isMuted }
        set { sound.isMuted = newValue }
    }

    // MARK: Titles

    /// Opens the shape and plays the titles, unless the person is coming back mid-tour.
    func begin() {
        sound.prepare()
        startPolling()
        let resuming = step != .welcome
        titles = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(450))
            guard let self, !Task.isCancelled else { return }
            if resuming {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.86)) {
                    self.phase = .tour
                    self.beat = .settle
                }
                return
            }
            withAnimation(.spring(response: 0.8, dampingFraction: 0.86)) { self.phase = .titles }
            await self.play(.painting, after: 0.6, animation: .easeOut(duration: 2.4))
            await self.play(.credit, after: 1.2, animation: .easeOut(duration: 1.0))
            await self.play(.wordmark, after: 2.8, animation: .easeInOut(duration: 0.8))
            self.sound.play(.shimmer)
            await self.play(.settle, after: 3.6, animation: .smooth(duration: 1.1))
            withAnimation(.smooth(duration: 0.9)) { self.phase = .tour }
        }
    }

    private func play(_ beat: TitleBeat, after seconds: Double, animation: Animation) async {
        try? await Task.sleep(for: .seconds(seconds))
        guard !Task.isCancelled else { return }
        withAnimation(animation) { self.beat = beat }
    }

    func skipTitles() {
        titles?.cancel()
        withAnimation(.smooth(duration: 0.7)) {
            beat = .settle
            phase = .tour
        }
    }

    // MARK: Pages

    func advance() {
        guard phase == .tour else { return }
        guard let next = step.next else { return finish() }
        go(to: next)
    }

    func back() {
        guard phase == .tour, let previous = OnboardingStep(rawValue: step.rawValue - 1) else { return }
        go(to: previous)
    }

    private func go(to target: OnboardingStep) {
        movingBack = target.rawValue < step.rawValue
        sound.play(.tick)
        withAnimation(.smooth(duration: 0.55)) { step = target }
        UserDefaults.standard.set(target.rawValue, forKey: Self.stepKey)
        if target == .done { sound.play(.fanfare) }
    }

    /// Return: the page's main button.
    func primary() {
        if step == .disk, !fullDiskAccess { return openFullDiskAccess() }
        advance()
    }

    /// ⌃⌥C pressed while the tour is up (the notch itself stays out of the way).
    func noteShortcut() {
        guard step == .shortcut else { return }
        shortcutPresses += 1
        guard !triedShortcut else { return }
        sound.play(.success)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { triedShortcut = true }
    }

    /// Folds the panel back into the notch, then hands over to it.
    func finish() {
        guard phase != .leaving else { return }
        UserDefaults.standard.set(true, forKey: Self.completedKey)
        UserDefaults.standard.removeObject(forKey: Self.stepKey)
        // A notch app is meant to be there every time; Ajustes turns this off.
        if !AppLocation.needsMove, SMAppService.mainApp.status != .enabled {
            try? SMAppService.mainApp.register()
        }
        poller?.cancel()
        withAnimation(.spring(response: 0.55, dampingFraction: 0.9)) { phase = .leaving }
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(700))
            self?.onFinish()
            try? await Task.sleep(for: .seconds(3))
            self?.sound.stop()
        }
    }

    // MARK: Permissions

    func openFullDiskAccess() {
        NSWorkspace.shared.open(FullDiskAccess.settingsURL)
    }

    func requestAccessibility() {
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    func requestNotifications() async {
        await LowDiskAlert.requestPermission()
        await refreshNotifications()
    }

    /// Grants land in System Settings, outside Cleen, so the tour looks again every
    /// second and celebrates the moment one comes through.
    private func startPolling() {
        poller?.cancel()
        poller = Task { [weak self] in
            await self?.refreshNotifications()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                self?.refresh()
            }
        }
    }

    private func refresh() {
        let disk = FullDiskAccess.isGranted
        if disk != fullDiskAccess {
            if disk { sound.play(.success) }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { fullDiskAccess = disk }
            // Back from System Settings: bring the tour to the front again.
            if disk, step == .disk { NSApp.activate() }
        }
        let trusted = AXIsProcessTrusted()
        if trusted != accessibility {
            if trusted { sound.play(.success) }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { accessibility = trusted }
        }
    }

    private func refreshNotifications() async {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        let granted = status == .authorized || status == .provisional
        if granted != notifications {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { notifications = granted }
        }
    }
}
