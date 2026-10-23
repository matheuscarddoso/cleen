import Foundation

/// One widget placed on Início.
struct HomeWidgetItem: Codable, Identifiable, Hashable {
    var kind: HomeWidgetKind
    var size: HomeWidgetSize

    var id: HomeWidgetKind { kind }

    init(_ kind: HomeWidgetKind, size: HomeWidgetSize? = nil) {
        self.kind = kind
        self.size = size ?? kind.defaultSize
    }
}
