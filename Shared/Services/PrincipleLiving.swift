import Foundation

/// The lived record of a principle — which of the trailing twelve weeks saw
/// an intention serving it actually advance, and the most recent day it was
/// lived. Recomputed on every render (the `AspirationRollup` doctrine) from
/// activity alone: ticks and qualifying sessions. Intention *outcomes* are
/// deliberately never read — history stays narrative (the `Intention`
/// doctrine) — and reflective intentions contribute nothing rather than a
/// synthesized signal. Moments never light the strip either: testimony is
/// witnessed, never counted (see `Moment`). A hollow week is silence, not
/// debt.
enum PrincipleLiving {
    /// Weeks of history the lived underline renders.
    static let historyWeeks = 12

    /// One principle's lived record.
    struct Record: Equatable {
        /// One flag per trailing week, oldest first, the week containing
        /// `now` last — the underline's dots.
        let weeks: [Bool]
        /// The most recent day the principle was lived, nil until any
        /// activity exists — lifetime, not windowed to the strip.
        let lastLived: Date?
        /// The title of the intention that day's activity came through.
        let lastLivedVia: String?

        /// The count the underline is captioned with ("9 of 12").
        var livedCount: Int {
            weeks.count(where: { $0 })
        }
    }

    /// The record for `principle` across `intentions` — the owning
    /// aspiration's, any week, open or closed; intentions serving another
    /// principle or none are ignored.
    static func record(
        for principle: Principle,
        in intentions: [Intention],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Record {
        let events = intentions
            .filter { $0.principle === principle }
            .flatMap { livedEvents(of: $0, calendar: calendar) }
        let livedWeeks = Set(events.map {
            Intention.weekStart(containing: $0.date, calendar: calendar)
        })
        let starts = AspirationAlignment.trailingWeekStarts(
            weeks: historyWeeks, now: now, calendar: calendar
        )
        let latest = events.max { $0.date < $1.date }
        return Record(
            weeks: starts.map { livedWeeks.contains($0) },
            lastLived: latest?.date,
            lastLivedVia: latest?.via
        )
    }
}

// MARK: - Lived events

private extension PrincipleLiving {
    struct LivedEvent {
        let date: Date
        let via: String
    }

    /// The days one intention actually advanced: its ticks (counted), or its
    /// week's qualifying session starts (derived). Reflective intentions
    /// yield nothing — no activity exists to read, and none is synthesized.
    static func livedEvents(of intention: Intention, calendar: Calendar) -> [LivedEvent] {
        switch intention.kind {
        case .reflective:
            return []
        case .counted:
            return intention.tickDates.map { LivedEvent(date: $0, via: intention.title) }
        case .derived:
            guard let metric = intention.metric else { return [] }
            return IntentionProgress
                .qualifyingSessions(of: metric, in: intention.weekInterval(calendar: calendar))
                .map { LivedEvent(date: $0.startedAt, via: intention.title) }
        }
    }
}
