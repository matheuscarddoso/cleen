import EventKit
import SwiftUI

struct AgendaStep: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(AgendaModel.self) private var agenda

    var body: some View {
        OnboardingPage(
            title: String(localized: "Seu dia, no notch"),
            message: String(localized: "Com o Calendário e os Lembretes, o Início mostra o próximo compromisso e o que falta fazer hoje."),
            primary: String(localized: "Continuar")
        ) {
            VStack(alignment: .leading, spacing: 4) {
                OnboardingRow(symbol: "calendar", title: String(localized: "Calendário"), note: String(localized: "Eventos de hoje e do mês")) {
                    PermissionControl(granted: calendarGranted) {
                        Task {
                            await agenda.requestCalendarAccess()
                            if calendarGranted { model.sound.play(.success) }
                        }
                    }
                }
                OnboardingRow(symbol: "checklist", title: String(localized: "Lembretes"), note: String(localized: "Marque como feito direto do notch")) {
                    PermissionControl(granted: remindersGranted) {
                        Task {
                            await agenda.requestRemindersAccess()
                            if remindersGranted { model.sound.play(.success) }
                        }
                    }
                }
                OnboardingRow(symbol: "bell.badge", title: String(localized: "Notificações"), note: String(localized: "Um aviso quando o disco estiver quase cheio")) {
                    PermissionControl(granted: model.notifications) {
                        Task { await model.requestNotifications() }
                    }
                }
            }
        }
    }

    // The model only learns the status once it has asked; the store knows it already.
    private var calendarGranted: Bool {
        agenda.calendarAccess == .granted || EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    private var remindersGranted: Bool {
        agenda.remindersAccess == .granted || EKEventStore.authorizationStatus(for: .reminder) == .fullAccess
    }
}
