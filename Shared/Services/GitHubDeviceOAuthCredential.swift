import Foundation

nonisolated struct GitHubCredential: Codable, Equatable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date?
    let refreshExpiresAt: Date?

    init(accessToken: String, refreshToken: String? = nil, expiresAt: Date? = nil, refreshExpiresAt: Date? = nil) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.refreshExpiresAt = refreshExpiresAt
    }
}
