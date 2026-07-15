import CoreLocation
import Foundation

/// A one-shot location + reverse-geocode for a single moment. Pull, never
/// push: nothing runs until the composer's *Add location* chip is tapped, on
/// every single moment. It asks for When-In-Use only, at hundred-meter
/// accuracy — a place label needs no more — and never escalates: no Always, no
/// background, no continuous updates, no significant-change monitoring. All
/// CoreLocation stays in the iOS target so `Shared/` and the watch build never
/// learn it exists (`Moment` itself holds only plain doubles + a string).
@MainActor
final class MomentLocationReader: NSObject {
    /// What a successful tap yields: coordinates always, and a name when the
    /// reverse-geocode found one — empty otherwise, so the chip reads a
    /// generic label rather than lying.
    struct Place {
        let latitude: Double
        let longitude: Double
        let name: String
    }

    /// The tap's result. `.denied` earns the composer's Settings footnote;
    /// `.failed` (authorized but no fix) is a quiet no-op; a geocode miss is
    /// not a failure — it still `.resolved`s, with an empty name.
    enum Outcome {
        case resolved(Place)
        case denied
        case failed
    }

    private let manager = CLLocationManager()
    private var authContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?
    private var fixContinuation: CheckedContinuation<CLLocation?, Never>?
    /// Whether a `resolve()` is in flight. The continuations above are
    /// single-slot, so a re-entrant call would overwrite — and thereby leak —
    /// a pending one; the guard lives here, with the state it protects,
    /// rather than in a caller's `.disabled` modifier.
    private var isResolving = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// The whole one-shot: authorize (prompting once when undetermined), take a
    /// single fix, reverse-geocode it once. A call that overlaps a pending one
    /// reports `.failed` instead of disturbing it.
    func resolve() async -> Outcome {
        guard !isResolving else { return .failed }
        isResolving = true
        defer { isResolving = false }
        guard await ensureAuthorized() else { return .denied }
        guard let location = await requestFix() else { return .failed }
        return .resolved(await place(from: location))
    }
}

// MARK: - Authorization

private extension MomentLocationReader {
    /// Whether When-In-Use is granted — the session-scoped "Allow Once" reads
    /// as the same grant — prompting once when the choice hasn't been made.
    func ensureAuthorized() async -> Bool {
        let status = manager.authorizationStatus
        guard status == .notDetermined else { return Self.isGranted(status) }
        let resolved = await withCheckedContinuation { continuation in
            authContinuation = continuation
            manager.requestWhenInUseAuthorization()
        }
        return Self.isGranted(resolved)
    }

    static func isGranted(_ status: CLAuthorizationStatus) -> Bool {
        status == .authorizedWhenInUse || status == .authorizedAlways
    }
}

// MARK: - Single fix & geocode

private extension MomentLocationReader {
    func requestFix() async -> CLLocation? {
        await withCheckedContinuation { continuation in
            fixContinuation = continuation
            manager.requestLocation()
        }
    }

    func place(from location: CLLocation) async -> Place {
        Place(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            name: await reverseGeocode(location)
        )
    }

    /// Geocodes once, at capture. A failed or offline lookup yields an empty
    /// name; the coordinates are kept regardless, and display never geocodes
    /// again.
    func reverseGeocode(_ location: CLLocation) async -> String {
        let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first
        return placemark.map(Self.label(from:)) ?? ""
    }

    /// "Golden Gate Bridge, San Francisco" — best-effort name plus locality,
    /// the locality dropped when it only repeats the name.
    static func label(from placemark: CLPlacemark) -> String {
        var parts: [String] = []
        if let name = placemark.name { parts.append(name) }
        if let locality = placemark.locality, locality != placemark.name {
            parts.append(locality)
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - CLLocationManagerDelegate

extension MomentLocationReader: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in resumeAuth(status) }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]
    ) {
        let location = locations.last
        Task { @MainActor in resumeFix(location) }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager, didFailWithError error: Error
    ) {
        Task { @MainActor in resumeFix(nil) }
    }
}

// MARK: - Continuation plumbing

private extension MomentLocationReader {
    /// The initial delegate callback (fired on delegate assignment, status
    /// still undetermined) has no waiter and is ignored; only a settled choice
    /// resumes.
    func resumeAuth(_ status: CLAuthorizationStatus) {
        guard status != .notDetermined, let continuation = authContinuation else { return }
        authContinuation = nil
        continuation.resume(returning: status)
    }

    func resumeFix(_ location: CLLocation?) {
        guard let continuation = fixContinuation else { return }
        fixContinuation = nil
        continuation.resume(returning: location)
    }
}
