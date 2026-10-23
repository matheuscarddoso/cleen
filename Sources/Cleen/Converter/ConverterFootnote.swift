import CleenKit
import SwiftUI

/// The line under the boxes: the unit rate on the left ("1 km = 0,6214 mi"), and for
/// money, how fresh the rates are on the right.
struct ConverterFootnote: View {
    let model: ConverterModel

    var body: some View {
        HStack(spacing: 8) {
            if let rate = model.unitRateText {
                Text(rate)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            Spacer(minLength: 0)
            if model.category == .currency {
                ratesStatus
            } else {
                Text("Return copia o resultado")
            }
        }
        .font(NotchStyle.caption)
        .foregroundStyle(NotchStyle.tertiary)
        .lineLimit(1)
        .animation(.smooth(duration: 0.18), value: model.unitRateText)
    }

    @ViewBuilder
    private var ratesStatus: some View {
        HStack(spacing: 5) {
            switch model.ratesState {
            case .loading:
                ProgressView().controlSize(.mini)
                Text("Atualizando cotação")
            case .failed:
                Image(systemName: "wifi.slash")
                Text(publishedText.map { "Sem conexão · cotação de \($0)" } ?? "Sem conexão")
            case .idle:
                if let publishedText { Text("Cotação de \(publishedText) · BCE") }
            }
        }
        .help("Taxas de referência do Banco Central Europeu, via Frankfurter")
    }

    /// "22 de out."
    private var publishedText: String? {
        model.rates?.publishedOn?.formatted(.dateTime.day().month(.abbreviated).locale(.cleen))
    }
}

/// Moeda without any rates yet: downloading, or offline with a way to try again.
struct ConverterRatesUnavailable: View {
    let isLoading: Bool
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            if isLoading {
                ProgressView().controlSize(.small)
                Text("Buscando a cotação do dia")
                    .font(.system(size: 11.5))
                    .foregroundStyle(NotchStyle.secondary)
            } else {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 18))
                    .foregroundStyle(NotchStyle.tertiary)
                Text("Sem conexão para buscar a cotação")
                    .font(.system(size: 11.5))
                    .foregroundStyle(NotchStyle.secondary)
                Button("Tentar de novo", action: retry)
                    .buttonStyle(.notchSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
