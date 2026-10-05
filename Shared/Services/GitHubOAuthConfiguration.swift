import Foundation

nonisolated enum GitHubOAuthConfiguration {
    static var clientID: String {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "GitHubClientID") as? String else { return "" }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.contains("$(") ? "" : value
    }
}
