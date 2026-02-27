import SwiftUI

// MARK: - ContentView

struct ContentView: View {
    @State private var store = DataStore()

    var body: some View {
        TabView {
            CalendarTab(store: store)
                .tabItem {
                    Label("Kalender", systemImage: "calendar")
                }

            SubjectsTab(store: store)
                .tabItem {
                    Label("Fächer", systemImage: "book.fill")
                }

            StudyLogTab(store: store)
                .tabItem {
                    Label("Lernzeit", systemImage: "clock.fill")
                }

            StatisticsTab(store: store)
                .tabItem {
                    Label("Statistik", systemImage: "chart.bar.fill")
                }
        }
        .onAppear {
            NotificationHelper.requestPermission()
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
