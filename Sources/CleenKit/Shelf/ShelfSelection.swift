import CoreGraphics

/// Finder-style selection over an ordered row of items: click picks one, ⌘-click
/// toggles, ⇧-click takes the range from the last plain click, and a rubber band picks
/// what it touches. Pure value logic, so the tray view only reports what happened.
public struct ShelfSelection<ID: Hashable & Sendable>: Equatable, Sendable {
    /// How a click (or a band) combines with what's already selected.
    public enum Mode: Sendable {
        /// Plain click: only this.
        case replace
        /// ⌘: flips the item, keeps the rest.
        case toggle
        /// ⇧: from the anchor to here.
        case extend
    }

    public private(set) var ids: Set<ID> = []
    /// Where a ⇧-click range starts: the last item clicked without ⇧.
    public private(set) var anchor: ID?
    /// What was selected when the band started, so dragging the band back off an item
    /// gives it its old state instead of leaving it picked.
    private var bandBase: Set<ID> = []

    public init(_ ids: Set<ID> = []) {
        self.ids = ids
    }

    public var isEmpty: Bool { ids.isEmpty }
    public var count: Int { ids.count }

    public func contains(_ id: ID) -> Bool { ids.contains(id) }

    /// The selected items in the row's order.
    public func ordered(in order: [ID]) -> [ID] {
        order.filter(ids.contains)
    }

    public mutating func click(_ id: ID, mode: Mode, in order: [ID]) {
        switch mode {
        case .replace:
            ids = [id]
            anchor = id
        case .toggle:
            if ids.remove(id) == nil { ids.insert(id) }
            anchor = id
        case .extend:
            guard let anchor, let start = order.firstIndex(of: anchor), let end = order.firstIndex(of: id) else {
                click(id, mode: .replace, in: order)
                return
            }
            ids = Set(order[min(start, end)...max(start, end)])
        }
    }

    public mutating func selectAll(_ order: [ID]) {
        ids = Set(order)
        anchor = order.first
    }

    public mutating func clear() {
        ids = []
        anchor = nil
    }

    /// ← → with one item in mind: steps from the last selected item (the first one
    /// going left), or lands on an end when nothing is selected.
    public mutating func move(by offset: Int, in order: [ID]) {
        guard !order.isEmpty else { return }
        let indices = order.indices.filter { ids.contains(order[$0]) }
        let target: Int
        if let edge = offset < 0 ? indices.first : indices.last {
            target = min(max(edge + offset, 0), order.count - 1)
        } else {
            target = offset < 0 ? order.count - 1 : 0
        }
        click(order[target], mode: .replace, in: order)
    }

    /// Forgets items that left the row.
    public mutating func keep(_ order: [ID]) {
        let present = Set(order)
        ids.formIntersection(present)
        if let anchor, !present.contains(anchor) { self.anchor = nil }
    }

    // MARK: Rubber band

    public mutating func beginBand(mode: Mode) {
        bandBase = mode == .replace ? [] : ids
        if mode == .replace { ids = [] }
    }

    public mutating func updateBand(touching: Set<ID>, mode: Mode) {
        switch mode {
        case .replace: ids = touching
        case .extend: ids = bandBase.union(touching)
        case .toggle: ids = bandBase.symmetricDifference(touching)
        }
    }

    /// The rectangle between where the drag started and where the pointer is now.
    public static func band(from start: CGPoint, to end: CGPoint) -> CGRect {
        CGRect(x: min(start.x, end.x), y: min(start.y, end.y), width: abs(end.x - start.x), height: abs(end.y - start.y))
    }

    /// Items whose frame the band touches. A band still flat on one axis counts too:
    /// a straight sideways sweep through a row should pick it up.
    public static func touched(by band: CGRect, frames: [ID: CGRect]) -> Set<ID> {
        Set(frames.compactMap { id, frame in
            frame.minX <= band.maxX && band.minX <= frame.maxX && frame.minY <= band.maxY && band.minY <= frame.maxY ? id : nil
        })
    }
}
