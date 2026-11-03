import CoreAudio
import Darwin
import Foundation

/// Which processes are sending sound out right now, from Core Audio's process objects
/// (macOS 14.2+), told on every change.
///
/// Event-driven: one listener on the system's process list and one per process on
/// "is running output". Everything, Core Audio calls included, runs on a private serial
/// queue, so a slow HAL never blocks the main thread; state is confined to that queue.
public final class AudioProcessMonitor: @unchecked Sendable {
    private let queue = DispatchQueue(label: "app.cleen.audio-processes", qos: .utility)
    private var onChange: (@Sendable ([AudioProcess]) -> Void)?
    private var listListener: AudioObjectPropertyListenerBlock?
    private var outputListeners: [AudioObjectID: AudioObjectPropertyListenerBlock] = [:]
    /// Who a process object is never changes, so it's read once.
    private var identities: [AudioObjectID: (pid: Int32, parentPID: Int32, bundleID: String)] = [:]

    public init() {}

    /// Starts watching; `onChange` runs on a background queue with the full list, once
    /// right away and then after every change.
    public func start(_ onChange: @escaping @Sendable ([AudioProcess]) -> Void) {
        queue.async { [self] in
            guard self.onChange == nil else { return }
            self.onChange = onChange
            var address = Self.address(kAudioHardwarePropertyProcessObjectList)
            let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in self?.processListChanged() }
            guard AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, queue, block) == noErr else { return }
            listListener = block
            processListChanged()
        }
    }

    public func stop() {
        queue.async { [self] in
            if let listListener {
                var address = Self.address(kAudioHardwarePropertyProcessObjectList)
                AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, queue, listListener)
            }
            listListener = nil
            for object in Array(outputListeners.keys) { unwatch(object) }
            identities = [:]
            onChange = nil
        }
    }

    // MARK: On the queue

    private func processListChanged() {
        let objects = Set(Self.processObjects())
        for object in Array(outputListeners.keys) where !objects.contains(object) { unwatch(object) }
        for object in objects where outputListeners[object] == nil { watch(object) }
        report()
    }

    private func watch(_ object: AudioObjectID) {
        var address = Self.address(kAudioProcessPropertyIsRunningOutput)
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in self?.report() }
        guard AudioObjectAddPropertyListenerBlock(object, &address, queue, block) == noErr else { return }
        outputListeners[object] = block
        let pid = Self.read(kAudioProcessPropertyPID, of: object, as: pid_t.self) ?? 0
        identities[object] = (pid, Self.parent(of: pid), Self.bundleID(of: object))
    }

    private func unwatch(_ object: AudioObjectID) {
        guard let block = outputListeners.removeValue(forKey: object) else { return }
        identities[object] = nil
        // The object may already be gone with its process; then the listener went with it.
        var address = Self.address(kAudioProcessPropertyIsRunningOutput)
        AudioObjectRemovePropertyListenerBlock(object, &address, queue, block)
    }

    private func report() {
        guard let onChange else { return }
        let processes = identities.map { object, identity in
            let running = Self.read(kAudioProcessPropertyIsRunningOutput, of: object, as: UInt32.self) ?? 0
            return AudioProcess(pid: identity.pid, parentPID: identity.parentPID, bundleID: identity.bundleID, isRunningOutput: running != 0)
        }
        onChange(processes)
    }

    // MARK: Core Audio

    private static func address(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    }

    private static func processObjects() -> [AudioObjectID] {
        var address = address(kAudioHardwarePropertyProcessObjectList)
        var size: UInt32 = 0
        let system = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr, size > 0 else { return [] }
        var objects = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &objects) == noErr else { return [] }
        return Array(objects.prefix(Int(size) / MemoryLayout<AudioObjectID>.size))
    }

    private static func read<Value: FixedWidthInteger>(_ selector: AudioObjectPropertySelector, of object: AudioObjectID, as _: Value.Type) -> Value? {
        var address = address(selector)
        var size = UInt32(MemoryLayout<Value>.size)
        var value: Value = 0
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value
    }

    private static func parent(of pid: pid_t) -> Int32 {
        guard pid > 0 else { return 0 }
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size else { return 0 }
        return Int32(bitPattern: info.pbi_ppid)
    }

    private static func bundleID(of object: AudioObjectID) -> String {
        var address = address(kAudioProcessPropertyBundleID)
        var bundle: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, &bundle) == noErr, let bundle else { return "" }
        return bundle.takeRetainedValue() as String
    }
}
