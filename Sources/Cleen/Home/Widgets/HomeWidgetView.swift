import SwiftUI

/// One widget's content at its size.
struct HomeWidgetView: View {
    let item: HomeWidgetItem

    var body: some View {
        switch item.kind {
        case .nowPlaying: NowPlayingWidget(size: item.size)
        case .agenda:
            if item.size == .small { AgendaGlance() } else { NotchCalendar() }
        case .mirror: MirrorButton(width: item.size.width)
        case .disk: DiskWidget(size: item.size)
        case .aiUsage: AIUsageWidget(size: item.size)
        case .system: SystemWidget(size: item.size)
        case .timer: TimerWidget(size: item.size)
        case .note: NoteWidget(size: item.size)
        case .reminders: RemindersWidget(size: item.size)
        case .weather: WeatherWidget(size: item.size)
        case .agents: AgentsWidget(size: item.size)
        case .stocks: StocksWidget(size: item.size)
        }
    }
}
