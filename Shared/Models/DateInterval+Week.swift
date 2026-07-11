import Foundation

extension DateInterval {
    /// The near-unreachable fallback for a failed
    /// `dateInterval(of: .weekOfYear)` — kept in one place so 604800 isn't
    /// re-derived at call sites as a blessed pattern; real weeks vary
    /// across DST.
    static func approximateWeek(startingAt start: Date) -> DateInterval {
        DateInterval(start: start, duration: 7 * 24 * 3600)
    }
}
