import Foundation

/// A run of sessions that share one calendar day.
struct SessionDayGroup: Identifiable {
    let day: Date
    let sessions: [Session]

    var id: Date {
        day
    }
}

/// Groups session lists by calendar day so list sections can carry one
/// "Today / Yesterday / June 5" header instead of repeating the full date in
/// every row.
enum SessionDayGrouping {
    /// Groups sessions by the calendar day they started, newest day first,
    /// preserving the incoming order within each day.
    static func group(
        _ sessions: [Session],
        calendar: Calendar = .current
    ) -> [SessionDayGroup] {
        Dictionary(grouping: sessions) { calendar.startOfDay(for: $0.startedAt) }
            .map { SessionDayGroup(day: $0.key, sessions: $0.value) }
            .sorted { $0.day > $1.day }
    }

    /// "Today", "Yesterday", or a spelled-out date like "June 5"
    /// ("June 5, 2025" once the year differs).
    static func label(
        for day: Date,
        relativeTo now: Date = .now,
        calendar: Calendar = .current
    ) -> String {
        if calendar.isDate(day, inSameDayAs: now) {
            return "Today"
        }
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        if calendar.isDate(day, inSameDayAs: yesterday) {
            return "Yesterday"
        }
        return calendar.isDate(day, equalTo: now, toGranularity: .year)
            ? day.formatted(.dateTime.month(.wide).day())
            : day.formatted(.dateTime.month(.wide).day().year())
    }
}
