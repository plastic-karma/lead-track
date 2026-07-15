import WidgetKit

/// The one timeline shape every snapshot-backed complication shares: load
/// the cached snapshot, plan the entry dates (a live window only while a
/// timer the rendered content reacts to is running), map dates to entries,
/// and reload `.atEnd`.
extension ComplicationTimeline {
    static func timeline<Entry: TimelineEntry>(
        at now: Date = .now,
        isLive: (WatchSnapshot) -> Bool,
        makeEntry: (Date, WatchSnapshot) -> Entry
    ) -> Timeline<Entry> {
        let snapshot = WatchSnapshotCache.load()
        let dates = entryDates(from: now, hasRunningTimer: isLive(snapshot))
        return Timeline(
            entries: dates.map { makeEntry($0, snapshot) },
            policy: .atEnd
        )
    }
}
