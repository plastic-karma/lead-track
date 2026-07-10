import Foundation
#if canImport(os)
import os
#endif

/// Central logger for the phone-watch sync pipeline. Failures here used to
/// vanish in `try?`/guard paths, which made "the watch went blank" and "my
/// wrist log disappeared" undiagnosable in the field; every degraded path now
/// leaves a trace in a sysdiagnose. Compiles to a no-op where os.log is
/// unavailable (the Linux overlay).
enum SyncLog {
    #if canImport(os)
    private static let logger = Logger(
        subsystem: "plastickarma.lead-track",
        category: "watch-sync"
    )
    #endif

    /// Records a degraded-path failure. Messages carry identifiers and error
    /// descriptions only — never user content such as metric names.
    static func error(_ message: String) {
        #if canImport(os)
        logger.error("\(message, privacy: .public)")
        #endif
    }

    /// Records an expected-but-noteworthy event (queued delivery, a dropped
    /// replay) at notice level.
    static func notice(_ message: String) {
        #if canImport(os)
        logger.notice("\(message, privacy: .public)")
        #endif
    }
}
