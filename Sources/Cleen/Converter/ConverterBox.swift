import CleenKit
import SwiftUI

/// One side of the conversion: the big number with its unit picker underneath, on the
/// notch's card. The result side can be copied (hover shows the button).
struct ConverterBox<Value: View>: View {
    let units: [ConverterUnit]
    let selected: ConverterUnit
    let select: (String) -> Void
    let copied: Bool
    let copy: (() -> Void)?
    let value: Value
    @State private var isHovered = false

    init(
        units: [ConverterUnit],
        selected: ConverterUnit,
        select: @escaping (String) -> Void,
        copied: Bool = false,
        copy: (() -> Void)? = nil,
        @ViewBuilder value: () -> Value
    ) {
        self.units = units
        self.selected = selected
        self.select = select
        self.copied = copied
        self.copy = copy
        self.value = value()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            value
                .frame(maxWidth: .infinity, alignment: .leading)
            ConverterUnitMenu(units: units, selected: selected, select: select)
        }
        .padding(.leading, 14)
        .padding(.trailing, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(NotchStyle.card, in: .rect(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(NotchStyle.cardStroke)
        }
        .overlay(alignment: .topTrailing) {
            if let copy, isHovered || copied {
                copyBadge(copy)
                    .padding(6)
                    .transition(.opacity)
            }
        }
        .onHover { hovering in
            withAnimation(.smooth(duration: 0.15)) { isHovered = hovering }
        }
    }

    @ViewBuilder
    private func copyBadge(_ copy: @escaping () -> Void) -> some View {
        if copied {
            Label("Copiado", systemImage: "checkmark")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(NotchStyle.good)
                .padding(.horizontal, 8)
                .frame(height: 22)
                .background(NotchStyle.control, in: .capsule)
        } else {
            NotchIconButton(symbol: "doc.on.doc", help: String(localized: "Copiar resultado"), action: copy)
        }
    }
}

extension Font {
    /// The boxes' big number: tabular digits so the value doesn't jitter as it changes.
    static let converterValue = Font.system(size: 24, weight: .semibold).monospacedDigit()
}

/// The unit's name with a chevron, opening the list of units.
struct ConverterUnitMenu: View {
    let units: [ConverterUnit]
    let selected: ConverterUnit
    let select: (String) -> Void
    @State private var isHovered = false

    var body: some View {
        Menu {
            ForEach(units) { unit in
                let title = unit.name == unit.symbol ? unit.name : "\(unit.name) (\(unit.symbol))"
                Button {
                    select(unit.id)
                } label: {
                    if unit.id == selected.id {
                        Label(title, systemImage: "checkmark")
                    } else {
                        Text(title)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selected.name)
                    .font(.system(size: 11.5, weight: .medium))
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8.5, weight: .semibold))
            }
            .foregroundStyle(isHovered ? NotchStyle.primary : NotchStyle.secondary)
            .contentShape(.rect)
        }
        .menuStyle(.button)
        .buttonStyle(.borderless)
        .menuIndicator(.hidden)
        .fixedSize()
        .onHover { isHovered = $0 }
        .accessibilityLabel("Unidade: \(selected.name)")
    }
}
