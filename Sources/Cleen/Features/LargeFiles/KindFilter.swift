import CleenKit
import SwiftUI

/// Pill row for narrowing a file list by type.
struct KindFilter: View {
    @Binding var selection: FileKind?
    let kinds: [FileKind]

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                FilterPill(title: "Todos", isSelected: selection == nil) { selection = nil }
                ForEach(kinds, id: \.self) { kind in
                    FilterPill(title: kind.title, isSelected: selection == kind) { selection = kind }
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}
