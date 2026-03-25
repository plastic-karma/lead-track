import SwiftData
import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            MetricListView()
                .navigationDestination(for: Metric.self) { metric in
                    MetricDetailView(metric: metric)
                }
                .navigationDestination(for: Project.self) { project in
                    ProjectDetailView(project: project)
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
