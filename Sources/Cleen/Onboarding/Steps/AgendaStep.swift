import EventKit
import SwiftUI

struct AgendaStep: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(AgendaModel.self) private var agenda

    var body: some View {
        OnboardingPage(
            title: "Seu dia, no notch",
            message: "Com o Calendário e os Lembretes, o Início mostra o próximo compromisso e o que falta fazer hoje.",
            primary: "Continuar"
        ) {
            VStack(alignment: .leading, spacing: 4) {
                OnboardingRow(symbol: "calendar", title: "Calendário", note: "Eventos de hoje e do mês") {
                    PermissionControl(granted: calendarGranted) {
                        Task {
                            await agenda.requestCalendarAccess()
                            if calendarGranted { model.sound.play(.success) }
                        }
                    }
                }
                OnboardingRow(symbol: "checklist", title: "Lembretes", note: "Marque como feito direto do notch") {
                    PermissionControl(granted: remindersGranted) {
                        Task {
                            await agenda.requestRemindersAccess()
                            if remindersGranted { model.sound.play(.success) }
                        }
                    }
                }
                OnboardingRow(symbol: "bell.badge", title: "Notificações", note: "Um aviso quando o disco estiver quase cheio") {
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
