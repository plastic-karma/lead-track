import Foundation

/// Parses user-typed numeric text the way the decimal pad produces it.
///
/// The decimal pad's separator key follows the device locale (a comma in
/// German, French, …), but `Double.init(String)` understands only the dot —
/// so "1,5" silently fails to parse. This helper accepts both the locale's
/// decimal separator and the plain dot by normalizing to the dot before
/// parsing, staying deterministic on every platform the shared code builds
/// on (including Linux).
enum LocaleDoubleParser {
    /// The number the text spells, or nil when it doesn't spell one.
    static func parse(
        _ text: String,
        locale: Locale = .current
    ) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        return Double(normalizeSeparator(in: trimmed, locale: locale))
    }

    /// Rewrites the locale's decimal separator to "." so `Double.init` can
    /// read it. Text that already uses the dot passes through untouched;
    /// text mixing both separators ends up malformed and parses to nil,
    /// which keeps ambiguous input rejected rather than misread.
    private static func normalizeSeparator(
        in text: String,
        locale: Locale
    ) -> String {
        guard let separator = locale.decimalSeparator, separator != "." else {
            return text
        }
        return text.replacingOccurrences(of: separator, with: ".")
    }
}
