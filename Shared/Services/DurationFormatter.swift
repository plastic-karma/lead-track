import Foundation

enum DurationFormatter {
    static func format(_ interval: TimeInterval) -> String {
        let totalSeconds = max(Int(interval), 0)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        }
        if minutes > 0 {
            return String(format: "%dm %02ds", minutes, seconds)
        }
        return String(format: "%ds", seconds)
    }

    /// Compact form for tiny complication dials: "45m", "1h", "1h05"
    /// (`format`'s "45m 30s" is too wide for a ~30pt ring center).
    static func compact(_ interval: TimeInterval) -> String {
        let totalMinutes = max(Int(interval), 0) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours == 0 {
            return "\(minutes)m"
        }
        if minutes == 0 {
            return "\(hours)h"
        }
        return String(format: "%dh%02d", hours, minutes)
    }
}
