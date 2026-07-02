import Foundation

/// How an intention accrues — or deliberately refuses — progress during its
/// week.
enum IntentionKind: String, Codable, CaseIterable {
    /// Held in the head all week ("be present in the evenings"); no progress
    /// value exists, and closure is one human judgment at the review.
    case reflective
    /// Advanced by hand: the user ticks when the act counted. Human judgment
    /// is the filter — there are no session qualifiers to encode "long" walks.
    case counted
    /// Computed live from an existing metric's completed sessions.
    case derived
}

/// What a derived intention counts over its metric's week.
enum DerivedMode: String, Codable, CaseIterable {
    /// The number of qualifying sessions ("3 walks").
    case sessionCount
    /// The sum of tracking values, in the metric's native unit ("4h of yoga").
    case valueSum
}

/// How a closed intention ended. An intention closed by renewal ("set again")
/// carries no outcome at all — the numbers stood on their own.
enum IntentionOutcome: String, Codable, CaseIterable {
    case done
    case partly
    /// Released. A valid outcome, visually and verbally equal to done —
    /// never rendered as missed, failed, or broken.
    case letGo
}

extension IntentionOutcome {
    /// The outcome word the narrative history shows.
    var label: String {
        switch self {
        case .done: "done"
        case .partly: "partly"
        case .letGo: "let go"
        }
    }
}
