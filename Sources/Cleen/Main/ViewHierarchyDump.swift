import AppKit

/// Debug aid (`--dump-views`): prints the main window's AppKit view tree.
enum ViewHierarchyDump {
    static func dump(_ view: NSView, depth: Int = 0) {
        guard depth < 14 else { return }
        let indent = String(repeating: "  ", count: depth)
        var line = "\(indent)\(type(of: view)) \(view.frame.integral)"
        if let scroll = view as? NSScrollView {
            line += " SCROLL elastic=\(scroll.verticalScrollElasticity.rawValue) hasV=\(scroll.hasVerticalScroller) docH=\(Int(scroll.documentView?.frame.height ?? -1)) clipY=\(Int(scroll.contentView.bounds.origin.y))"
        }
        FileHandle.standardError.write(Data((line + "\n").utf8))
        view.subviews.forEach { dump($0, depth: depth + 1) }
    }
}
