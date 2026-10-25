import AppKit
import CleenKit

/// Lays a list item's hidden marker out as nothing and draws, in its place, a dot, a
/// checkbox or a quote bar.
nonisolated final class MarkdownLayoutManager: NSLayoutManager, NSLayoutManagerDelegate {
    var styler: MarkdownStyler

    init(styler: MarkdownStyler) {
        self.styler = styler
        super.init()
        delegate = self
    }

    required init?(coder: NSCoder) { nil }

    func layoutManager(
        _ layoutManager: NSLayoutManager,
        shouldGenerateGlyphs glyphs: UnsafePointer<CGGlyph>,
        properties: UnsafePointer<NSLayoutManager.GlyphProperty>,
        characterIndexes: UnsafePointer<Int>,
        font: NSFont,
        forGlyphRange glyphRange: NSRange
    ) -> Int {
        guard let storage = textStorage else { return 0 }
        var changed = false
        var adjusted = [NSLayoutManager.GlyphProperty](unsafeUninitializedCapacity: glyphRange.length) { buffer, count in
            for index in 0..<glyphRange.length {
                let character = characterIndexes[index]
                if character < storage.length, storage.attribute(.markdownHidden, at: character, effectiveRange: nil) != nil {
                    buffer[index] = .null
                    changed = true
                } else {
                    buffer[index] = properties[index]
                }
            }
            count = glyphRange.length
        }
        guard changed else { return 0 }
        return adjusted.withUnsafeMutableBufferPointer { buffer in
            setGlyphs(glyphs, properties: buffer.baseAddress!, characterIndexes: characterIndexes, font: font, forGlyphRange: glyphRange)
            return glyphRange.length
        }
    }

    override func drawGlyphs(forGlyphRange glyphsToShow: NSRange, at origin: NSPoint) {
        super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)
        guard let storage = textStorage else { return }
        let characters = characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)
        storage.enumerateAttribute(.markdownDecoration, in: characters) { value, range, _ in
            guard let encoded = value as? String, let decoration = MarkdownDecoration(encoded: encoded) else { return }
            draw(decoration, markerRange: range, origin: origin)
        }
    }

    /// The box the marker's line sits in, and where its text's baseline is. Measured on
    /// the first character after the marker: hidden glyphs can be laid out at the end
    /// of the line above. An empty item at the very end sits in the extra line fragment.
    func markerFrame(for markerRange: NSRange) -> (line: NSRect, baseline: CGFloat)? {
        guard let storage = textStorage else { return nil }
        let character = markerRange.upperBound
        if character < storage.length {
            let glyph = glyphIndexForCharacter(at: character)
            guard glyph < numberOfGlyphs else { return nil }
            return (lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil), location(forGlyphAt: glyph).y)
        }
        let extra = extraLineFragmentRect
        guard !extra.isEmpty else { return nil }
        return (extra, styler.baseFont.ascender)
    }

    /// The checkbox's square, in text-container coordinates.
    func checkboxRect(x: CGFloat, line: NSRect, baseline: CGFloat) -> NSRect {
        let side = styler.checkboxSide
        let center = line.minY + baseline - styler.baseFont.xHeight / 2
        return NSRect(x: x, y: center - side / 2, width: side, height: side)
    }

    private func draw(_ decoration: MarkdownDecoration, markerRange: NSRange, origin: NSPoint) {
        guard let frame = markerFrame(for: markerRange) else { return }
        let line = frame.line.offsetBy(dx: origin.x, dy: origin.y)
        let xHeightCenter = line.minY + frame.baseline - styler.baseFont.xHeight / 2
        switch decoration {
        case .bullet(let x, let width):
            // The dot sits where the hyphen was.
            let radius = styler.baseSize * 0.16
            let center = origin.x + x + width / 2
            NSColor.white.withAlphaComponent(0.7).setFill()
            NSBezierPath(ovalIn: NSRect(x: center - radius, y: xHeightCenter - radius, width: radius * 2, height: radius * 2)).fill()
        case .checkbox(let x, let checked):
            let box = checkboxRect(x: x, line: frame.line, baseline: frame.baseline).offsetBy(dx: origin.x, dy: origin.y)
            let path = NSBezierPath(roundedRect: box.insetBy(dx: 0.6, dy: 0.6), xRadius: box.width * 0.3, yRadius: box.width * 0.3)
            if checked {
                NSColor.white.withAlphaComponent(0.9).setFill()
                path.fill()
                let check = NSBezierPath()
                check.move(to: NSPoint(x: box.minX + box.width * 0.26, y: box.midY))
                check.line(to: NSPoint(x: box.minX + box.width * 0.43, y: box.minY + box.height * 0.7))
                check.line(to: NSPoint(x: box.minX + box.width * 0.76, y: box.minY + box.height * 0.3))
                check.lineWidth = box.width * 0.13
                check.lineCapStyle = .round
                check.lineJoinStyle = .round
                NSColor.black.setStroke()
                check.stroke()
            } else {
                path.lineWidth = 1.2
                NSColor.white.withAlphaComponent(0.5).setStroke()
                path.stroke()
            }
        case .quote(let x):
            NSColor.white.withAlphaComponent(0.25).setFill()
            NSBezierPath(roundedRect: NSRect(x: origin.x + x + 1, y: line.minY + 1, width: 2.5, height: line.height - 2), xRadius: 1.25, yRadius: 1.25).fill()
        }
    }
}

/// The note's editor, like Obsidian's Live Preview: the line with the cursor shows its
/// Markdown, the rest is rendered, and the cursor moves through plain text, never
/// around hidden characters. Shortcuts of Apple Notes (⇧⌘L checklist, ⇧⌘7 bullets,
/// ⇧⌘9 numbers, ⇧⌘U tick) and of Markdown editors (⌘B, ⌘I, ⇧⌘X, ⌘E for code). Return
/// continues a list and leaves it from an empty item, Tab nests an item, a click on a
/// checkbox ticks it.
final class MarkdownTextView: NSTextView {
    let styler: MarkdownStyler
    var onFocusChange: ((Bool) -> Void)?

    init(baseSize: CGFloat) {
        styler = MarkdownStyler(baseSize: baseSize)
        let storage = NSTextStorage()
        let layout = MarkdownLayoutManager(styler: styler)
        storage.addLayoutManager(layout)
        let container = NSTextContainer(size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        container.lineFragmentPadding = 0
        layout.addTextContainer(container)
        super.init(frame: .zero, textContainer: container)
        isRichText = false
        importsGraphics = false
        allowsUndo = true
        drawsBackground = false
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isVerticallyResizable = true
        isHorizontallyResizable = false
        autoresizingMask = [.width]
        insertionPointColor = .white
        typingAttributes = styler.baseAttributes
        selectedTextAttributes = [.backgroundColor: NSColor.white.withAlphaComponent(0.22)]
        setAccessibilityLabel(String(localized: "Nota"))
    }

    required init?(coder: NSCoder) { nil }

    private var markdownLayout: MarkdownLayoutManager? { layoutManager as? MarkdownLayoutManager }

    /// The lines showing their Markdown: the ones the selection touches.
    private var activeLines = NSRange(location: 0, length: 0)

    /// Restyles everything (a note loaded or switched).
    func restyle() {
        guard let storage = textStorage else { return }
        activeLines = currentLines()
        styler.style(storage, lines: NSRange(location: 0, length: storage.length), active: isEditing ? activeLines : NSRange(location: NSNotFound, length: 0))
        typingAttributes = styler.baseAttributes
    }

    /// Only the lines that can have changed: the edited one, the one just left, the one
    /// now under the cursor.
    private func restyle(around range: NSRange) {
        guard let storage = textStorage else { return }
        let previous = activeLines
        activeLines = currentLines()
        let length = storage.length
        func clamp(_ range: NSRange) -> NSRange {
            let location = min(range.location, length)
            return NSRange(location: location, length: min(range.length, length - location))
        }
        let touched = NSUnionRange(NSUnionRange(clamp(previous), clamp(activeLines)), clamp(range))
        styler.style(storage, lines: touched, active: isEditing ? activeLines : NSRange(location: NSNotFound, length: 0))
        typingAttributes = styler.baseAttributes
    }

    private var isEditing: Bool { window?.firstResponder === self }

    private func currentLines() -> NSRange {
        let selection = selectedRange()
        guard selection.location <= nsString.length else { return NSRange(location: 0, length: 0) }
        return nsString.lineRange(for: selection)
    }

    override func didChangeText() {
        // The edit and the line before it: Return leaves a line that now renders.
        let caret = selectedRange().location
        restyle(around: NSRange(location: max(0, caret - 1), length: 1))
        super.didChangeText()
        // Restyling can change line heights (a heading); keep the caret in sight.
        scrollRangeToVisible(selectedRange())
    }

    override func setSelectedRanges(_ ranges: [NSValue], affinity: NSSelectionAffinity, stillSelecting: Bool) {
        super.setSelectedRanges(ranges, affinity: affinity, stillSelecting: stillSelecting)
        guard textStorage != nil, currentLines() != activeLines else { return }
        restyle(around: currentLines())
    }

    override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        if became {
            onFocusChange?(true)
            restyle(around: currentLines())
        }
        return became
    }

    /// Leaving the note renders every line, the one that had the cursor too.
    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned {
            onFocusChange?(false)
            DispatchQueue.main.async { [weak self] in self?.restyle() }
        }
        return resigned
    }

    // MARK: Lines

    private var nsString: NSString { string as NSString }

    private func lineRange(at location: Int) -> NSRange {
        let range = nsString.lineRange(for: NSRange(location: location, length: 0))
        // Without its line break.
        var length = range.length
        while length > 0, let scalar = UnicodeScalar(nsString.character(at: range.location + length - 1)), CharacterSet.newlines.contains(scalar) { length -= 1 }
        return NSRange(location: range.location, length: length)
    }

    /// Replaces text as typing would, so it can be undone and the delegate hears of it.
    private func replace(_ range: NSRange, with text: String, caret: Int? = nil) {
        guard shouldChangeText(in: range, replacementString: text) else { return }
        textStorage?.replaceCharacters(in: range, with: text)
        didChangeText()
        if let caret { setSelectedRange(NSRange(location: caret, length: 0)) }
        scrollRangeToVisible(selectedRange())
    }

    /// Rewrites every line the selection touches, numbering them from 1.
    private func transformLines(_ transform: (String, Int) -> String) {
        let lines = nsString.lineRange(for: selectedRange())
        let original = nsString.substring(with: lines)
        let trailingBreak = original.hasSuffix("\n")
        let body = trailingBreak ? String(original.dropLast()) : original
        let text = body.components(separatedBy: "\n").enumerated()
            .map { transform($0.element, $0.offset + 1) }
            .joined(separator: "\n")
        replace(lines, with: text + (trailingBreak ? "\n" : ""))
        setSelectedRange(NSRange(location: lines.location + (text as NSString).length, length: 0))
    }

    // MARK: Typing

    override func insertNewline(_ sender: Any?) {
        let caret = selectedRange()
        let range = lineRange(at: caret.location)
        guard caret.length == 0, caret.location == range.upperBound else { return super.insertNewline(sender) }
        switch MarkdownLine(nsString.substring(with: range)).continuation {
        case .none:
            super.insertNewline(sender)
        case .insert(let prefix):
            replace(caret, with: "\n" + prefix, caret: caret.location + 1 + (prefix as NSString).length)
        case .end:
            replace(range, with: "", caret: range.location)
        }
    }

    override func insertText(_ string: Any, replacementRange: NSRange) {
        super.insertText(string, replacementRange: replacementRange)
        guard (string as? String) == " " else { return }
        let caret = selectedRange().location
        let range = lineRange(at: caret)
        let typed = nsString.substring(with: NSRange(location: range.location, length: caret - range.location))
        if let expanded = MarkdownLine.expandingShortcut(typed) {
            replace(NSRange(location: range.location, length: caret - range.location), with: expanded, caret: range.location + (expanded as NSString).length)
        }
    }

    /// Backspace at the start of an item's words drops its marker, like Notes.
    override func deleteBackward(_ sender: Any?) {
        let caret = selectedRange()
        let range = lineRange(at: caret.location)
        let line = MarkdownLine(nsString.substring(with: range))
        if caret.length == 0, line.markerLength > 0, caret.location == range.location + line.prefixLength, line.isListItem || line.kind == .quote {
            replace(NSRange(location: range.location, length: line.prefixLength), with: "", caret: range.location)
            return
        }
        super.deleteBackward(sender)
    }

    override func insertTab(_ sender: Any?) {
        guard MarkdownLine(nsString.substring(with: lineRange(at: selectedRange().location))).isListItem else { return super.insertTab(sender) }
        let caret = selectedRange()
        let range = lineRange(at: caret.location)
        replace(NSRange(location: range.location, length: 0), with: "  ", caret: caret.location + 2)
    }

    override func insertBacktab(_ sender: Any?) {
        let caret = selectedRange()
        let range = lineRange(at: caret.location)
        let line = MarkdownLine(nsString.substring(with: range))
        guard line.isListItem, line.indent > 0 else { return }
        let remove = min(2, line.indent)
        replace(NSRange(location: range.location, length: remove), with: "", caret: max(range.location, caret.location - remove))
    }

    // MARK: Shortcuts

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard window?.firstResponder === self else { return super.performKeyEquivalent(with: event) }
        let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""
        switch (flags, key) {
        case ([.command], "b"): wrap("**")
        case ([.command], "i"): wrap("*")
        case ([.command], "e"): wrap("`")
        case ([.command, .shift], "x"): wrap("~~")
        case ([.command, .shift], "l"): transformLines { line, _ in MarkdownLine.applying(.checklist, to: line) }
        case ([.command, .shift], "7"), ([.command, .shift], "&"): transformLines { line, _ in MarkdownLine.applying(.bullet, to: line) }
        case ([.command, .shift], "9"), ([.command, .shift], "("): transformLines { line, number in MarkdownLine.applying(.numbered, to: line, number: number) }
        case ([.command, .shift], "u"): transformLines { line, _ in MarkdownLine.togglingCheckbox(line) ?? line }
        default: return super.performKeyEquivalent(with: event)
        }
        return true
    }

    /// Wraps the selection in a marker, or unwraps it; with nothing selected, leaves the
    /// caret between a pair to type into.
    private func wrap(_ marker: String) {
        let selection = selectedRange()
        let length = (marker as NSString).length
        let selected = nsString.substring(with: selection)
        if selected.hasPrefix(marker), selected.hasSuffix(marker), (selected as NSString).length >= length * 2 {
            let inner = String(selected.dropFirst(marker.count).dropLast(marker.count))
            replace(selection, with: inner)
            setSelectedRange(NSRange(location: selection.location, length: (inner as NSString).length))
            return
        }
        replace(selection, with: marker + selected + marker)
        setSelectedRange(NSRange(location: selection.location + length, length: selection.length))
    }

    // MARK: Checkboxes

    override func mouseDown(with event: NSEvent) {
        if toggleCheckbox(at: convert(event.locationInWindow, from: nil)) { return }
        super.mouseDown(with: event)
    }

    /// A click on a checkbox ticks it without moving the caret: the drawn box on a
    /// rendered line, or the "[ ]" itself on the line being edited.
    private func toggleCheckbox(at point: NSPoint) -> Bool {
        guard let layout = markdownLayout, let container = textContainer, let storage = textStorage, storage.length > 0 else { return false }
        let inContainer = NSPoint(x: point.x - textContainerOrigin.x, y: point.y - textContainerOrigin.y)
        let glyph = layout.glyphIndex(for: inContainer, in: container)
        let character = min(layout.characterIndexForGlyph(at: glyph), storage.length - 1)
        let range = lineRange(at: character)
        let source = nsString.substring(with: range)
        let line = MarkdownLine(source)
        guard case .checklist = line.kind else { return false }
        let hit: Bool
        if let encoded = storage.attribute(.markdownDecoration, at: range.location, effectiveRange: nil) as? String,
           case .checkbox(let x, _) = MarkdownDecoration(encoded: encoded),
           let frame = layout.markerFrame(for: NSRange(location: range.location, length: line.prefixLength)) {
            hit = layout.checkboxRect(x: x, line: frame.line, baseline: frame.baseline).insetBy(dx: -5, dy: -4).contains(inContainer)
        } else {
            // Shown as text: "- [ ]" from the hyphen to the bracket.
            var fraction: CGFloat = 0
            let index = layout.characterIndex(for: inContainer, in: container, fractionOfDistanceBetweenInsertionPoints: &fraction)
            hit = index >= range.location + line.indent && index < range.location + line.indent + 5
        }
        guard hit, let toggled = MarkdownLine.togglingCheckbox(source) else { return false }
        let caret = selectedRange()
        replace(range, with: toggled)
        setSelectedRange(caret)
        return true
    }
}
