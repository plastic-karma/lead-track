import Foundation
#if canImport(os)
import os
#endif

/// Central logger for the notification pipeline. Scheduling failures used to
/// vanish in discarded completion handlers, which made "my reminder never
/// fired" undiagnosable in the field; every degraded path now leaves a trace
/// in a sysdiagnose. Compiles to a no-op where os.log is unavailable (the
/// Linux overlay).
enum NotifyLog {
    #if canImport(os)
    private static let logger = Logger(
        subsystem: "plastickarma.lead-track",
        category: "notifications"
    )
    #endif

    /// Records a degraded-path failure. Messages carry request identifiers
    /// and error descriptions only — never user content such as metric names.
    static func error(_ message: String) {
        #if canImport(os)
        logger.error("\(message, privacy: .public)")
        #endif
    }

    /// Records an expected-but-noteworthy event (permission not granted) at
    /// notice level.
    static func notice(_ message: String) {
        #if canImport(os)
        logger.notice("\(message, privacy: .public)")
        #endif
    }
}
