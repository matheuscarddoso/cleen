import SwiftUI

struct SpaceBreadcrumbs: View {
    @Environment(SpaceLensModel.self) private var model

    var body: some View {
        let crumbs = model.breadcrumbs
        HStack(spacing: 5) {
            if crumbs.count > 1 {
                NotchIconButton(symbol: "chevron.left", help: "Voltar", action: model.goUp)
            }
            ScrollView(.horizontal) {
                HStack(spacing: 4) {
                    ForEach(crumbs.indices, id: \.self) { index in
                        if index > 0 {
                            Image(systemName: "chevron.compact.right")
                                .font(.system(size: 10))
                                .foregroundStyle(NotchStyle.tertiary)
                        }
                        Button(index == 0 ? model.target.title : crumbs[index].name) { model.goBack(to: index) }
                            .buttonStyle(.plain)
                            .font(.system(size: 11.5, weight: index == crumbs.count - 1 ? .semibold : .medium))
                            .foregroundStyle(index == crumbs.count - 1 ? NotchStyle.primary : NotchStyle.secondary)
                    }
                }
            }
            .scrollIndicators(.hidden)
            Spacer(minLength: 6)
            Text(crumbs.last?.size.bytes ?? "")
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
            Menu {
                Button("Sua pasta pessoal") { model.scan(.home) }
                Button("Disco inteiro") { model.scan(.disk) }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(NotchStyle.secondary)
            }
            .menuStyle(.button)
            .buttonStyle(.borderless)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Mapear de novo")
        }
        .frame(height: 24)
    }
}
