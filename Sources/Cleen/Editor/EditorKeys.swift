import AppKit

/// What each key does in the editor.
///
/// Space or Return play and pause; ⌥ held is the scissors; C or S split at the playhead;
/// ⌫ removes what's selected; ← → step a frame (with ⇧, a second); ↑ ↓ (or Home, End)
/// go to the start and the end; + and − zoom the timeline; Esc lets go.
enum EditorKeys {
    @MainActor
    static func handle(_ event: NSEvent, editor: EditorModel) -> Bool {
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        // ⌘ shortcuts (undo, export…) belong to the menus and buttons.
        guard !flags.contains(.command), !flags.contains(.control) else { return false }
        let shift = flags.contains(.shift)
        switch event.keyCode {
        case 49, 36, 76: // space, return, enter
            editor.togglePlay()
        case 51, 117: // delete, forward delete
            guard editor.selection != nil else { return false }
            editor.removeSelection()
        case 53: // esc
            if editor.isCuttingLocked {
                editor.isCuttingLocked = false
            } else if editor.selection != nil {
                editor.selection = nil
            } else {
                return false
            }
        case 123: // ←
            shift ? editor.seek(to: editor.currentTime - 1) : editor.step(frames: -1)
        case 124: // →
            shift ? editor.seek(to: editor.currentTime + 1) : editor.step(frames: 1)
        case 126, 115: // ↑, home
            editor.seek(to: 0)
        case 125, 119: // ↓, end
            editor.seek(to: editor.duration)
        default:
            switch event.charactersIgnoringModifiers?.lowercased() {
            case "c", "s":
                editor.split(at: editor.currentTime)
            case "+", "=":
                editor.timelineZoom = min(10, editor.timelineZoom * 1.4)
            case "-", "_":
                editor.timelineZoom = max(1, editor.timelineZoom / 1.4)
            default:
                return false
            }
        }
        return true
    }
}
