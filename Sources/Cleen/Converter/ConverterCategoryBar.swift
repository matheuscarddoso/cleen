import CleenKit
import SwiftUI

/// The nine categories as one segmented row. It fits the default panel; if a narrower
/// layout ever cuts it, it scrolls sideways with soft edges instead of wrapping.
struct ConverterCategoryBar: View {
    @Binding var selection: ConverterCategory

    var body: some View {
        ScrollView(.horizontal) {
            NotchSegmented(options: ConverterCategory.allCases.map { ($0.title, $0) }, selection: $selection)
        }
        .scrollIndicators(.never)
        .scrollBounceBehavior(.basedOnSize)
        .scrollEdgeFade(.horizontal, length: 28)
        .fixedSize(horizontal: false, vertical: true)
    }
}
