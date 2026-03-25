import SwiftData
import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            WatchMetricListView()
                .navigationDestination(for: Metric.self) { metric in
                    WatchActiveSessionView(metric: metric)
                }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(
            for: [Metric.self, Project.self, Session.self],
            inMemory: true
        )
}
