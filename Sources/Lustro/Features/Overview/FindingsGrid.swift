import LustroKit
import SwiftUI

/// One card per area the smart scan covered, each a door into its section.
struct FindingsGrid: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: "O que a análise encontrou")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 12)], spacing: 12) {
                FindingCard(
                    route: .junk,
                    value: app.junk.phase == .ready ? app.junk.totalSize.bytes : nil,
                    detail: "Caches, logs, instaladores e restos do Xcode e do npm.",
                    open: open
                )
                FindingCard(
                    route: .projects,
                    value: app.projects.phase == .ready ? app.projects.staleSize.bytes : nil,
                    detail: projectsDetail,
                    open: open
                )
                FindingCard(
                    route: .leftovers,
                    value: app.orphans.phase == .ready ? app.orphans.totalSize.bytes : nil,
                    detail: app.orphans.groups.isEmpty ? "Nenhum resto de app removido." : "Dados de \(app.orphans.groups.count) apps que já não estão no Mac.",
                    open: open
                )
                FindingCard(
                    route: .startup,
                    value: app.startup.phase == .ready ? "\(app.startup.items.count)" : nil,
                    detail: startupDetail,
                    detailIsWarning: !app.startup.suspicious.isEmpty,
                    open: open
                )
            }
        }
    }

    private var projectsDetail: String {
        let stale = app.projects.projects.count { $0.isStale(threshold: app.projects.staleThreshold) }
        if stale == 0 { return "Nenhum projeto parado com dependências instaladas." }
        return "Dependências de \(stale) projetos parados há mais de \(app.projects.staleDays) dias."
    }

    private var startupDetail: String {
        guard app.startup.phase == .ready else { return "Lendo o que abre sozinho…" }
        let suspicious = app.startup.suspicious.count
        if suspicious > 0 {
            return suspicious == 1 ? "1 item sem assinatura confiável." : "\(suspicious) itens sem assinatura confiável."
        }
        return "Itens que abrem sozinhos. Todos assinados."
    }

    private func open(_ route: Route) {
        app.route = route
    }
}
