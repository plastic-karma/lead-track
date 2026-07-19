import SwiftUI

/// The calendar's toolbar filter: judge every daily goal, one metric, one
/// project (grouped under its metric), or one aspiration. The active choice
/// wears a checkmark and fills the toolbar glyph.
struct GoalCalendarFilterMenu: View {
    let metrics: [Metric]
    let aspirations: [Aspiration]
    @Binding var filter: GoalCalendarFilter?

    var body: some View {
        Menu {
            row("All Daily Goals", candidate: nil)
            metricsSubmenu
            projectsSubmenu
            aspirationsSubmenu
        } label: {
            Label(
                "Filter",
                systemImage: filter == nil
                    ? "line.3.horizontal.decrease.circle"
                    : "line.3.horizontal.decrease.circle.fill"
            )
        }
    }
}

// MARK: - Pieces

extension GoalCalendarFilterMenu {
    private func row(_ title: String, candidate: GoalCalendarFilter?) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) {
                filter = candidate
            }
        } label: {
            if filter == candidate {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
    }

    @ViewBuilder
    private var metricsSubmenu: some View {
        let listed = metrics.unarchived
        if !listed.isEmpty {
            Menu("Metrics") {
                ForEach(listed) { metric in
                    row(metric.name, candidate: .metric(metric))
                }
            }
        }
    }

    @ViewBuilder
    private var projectsSubmenu: some View {
        let owners = metrics.unarchived.filter { !$0.projects.isEmpty }
        if !owners.isEmpty {
            Menu("Projects") {
                ForEach(owners) { metric in
                    Section(metric.name) {
                        ForEach(metric.projects.inDisplayOrder) { project in
                            row(project.name, candidate: .project(project))
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var aspirationsSubmenu: some View {
        if !aspirations.isEmpty {
            Menu("Aspirations") {
                ForEach(aspirations.inDisplayOrder) { aspiration in
                    row(aspiration.title, candidate: .aspiration(aspiration))
                }
            }
        }
    }
}
