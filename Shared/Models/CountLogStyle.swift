import Foundation

/// What a count metric's primary log action does, chosen per metric in its
/// settings: metrics logged one at a time ("one more prayer") want a single
/// tap, metrics logged in varying amounts ("500 words written") want to be
/// asked how many.
enum CountLogStyle: String, Codable, CaseIterable {
    /// The primary action opens the amount entry; a quick +1 stays one
    /// step away. The only behavior before the setting existed.
    case askAmount
    /// The primary action logs a single unit immediately; entering a custom
    /// amount stays one step away.
    case incrementByOne
}
