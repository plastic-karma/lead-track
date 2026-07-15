import Foundation

/// The deep link a watch-face complication carries so tapping it opens the
/// watch app on the metric it shows, instead of the root list. Shared by the
/// Metric Progress complication (which builds the URL) and the watch app
/// (which parses it on `onOpenURL`) so the two encodings can't drift apart.
enum WatchMetricDeepLink {
    private static let scheme = "leadstone"
    private static let host = "metric"

    /// `leadstone://metric/<uuid>` for the given metric, or nil in the
    /// theoretical case the identifier can't form a valid URL (a UUID always
    /// can, so callers can treat nil as "no deep link").
    static func url(metricID: UUID) -> URL? {
        URL(string: "\(scheme)://\(host)/\(metricID.uuidString)")
    }

    /// The metric identifier a complication URL points at, or nil when the
    /// URL isn't one of ours or its last path component isn't a valid UUID.
    /// Parsed through `URLComponents` so the reading matches on both Apple
    /// platforms and the Linux overlay (`URL.host` is deprecated on the
    /// former and its replacement absent on the latter).
    static func metricID(from url: URL) -> UUID? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == scheme,
              components.host == host
        else { return nil }
        return UUID(uuidString: url.lastPathComponent)
    }
}
