import Foundation

nonisolated struct VaultConfiguration: Codable, Equatable {
    var owner: String
    var repository: String
    var branch: String
    var folder: String

    var identity: String {
        "\(owner.lowercased())/\(repository.lowercased())@\(branch):\(folder)"
    }

    func validated() throws -> Self {
        let result = Self(
            owner: owner.trimmingCharacters(in: .whitespacesAndNewlines),
            repository: repository.trimmingCharacters(in: .whitespacesAndNewlines),
            branch: branch.trimmingCharacters(in: .whitespacesAndNewlines),
            folder: folder.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        let nameCharacters =
            CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.")
        for name in [result.owner, result.repository] {
            guard !name.isEmpty, name != ".", name != "..",
                  name.unicodeScalars.allSatisfy(nameCharacters.contains)
            else {
                throw VaultError.invalid("Enter a GitHub owner and repository name, not a URL.")
            }
        }
        try Self.validateBranch(result.branch)
        try Self.validatePath(result.folder)
        return result
    }

    static func validatePath(_ path: String) throws {
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        let invalid = CharacterSet.controlCharacters.union(CharacterSet(charactersIn: "\\:*?\"<>|"))
        guard !path.isEmpty, path.unicodeScalars.allSatisfy({ !invalid.contains($0) }),
              components.allSatisfy({
                  !$0.isEmpty && $0 != "." && $0 != ".." && $0.lowercased() != ".git"
                      && $0.lowercased() != ".obsidian"
              })
        else {
            throw VaultError.invalid("Use a nonempty relative vault path without traversal or reserved folders.")
        }
    }

    private static func validateBranch(_ name: String) throws {
        let invalid = CharacterSet.whitespacesAndNewlines.union(.controlCharacters)
            .union(CharacterSet(charactersIn: "~^:?*[\\"))
        let components = name.split(separator: "/", omittingEmptySubsequences: false)
        guard !name.isEmpty, name != "@", !name.contains(".."), !name.contains("@{"),
              !name.hasSuffix("."), name.unicodeScalars.allSatisfy({ !invalid.contains($0) }),
              components.allSatisfy({ !$0.isEmpty && !$0.hasPrefix(".") && !$0.hasSuffix(".lock") })
        else {
            throw VaultError.invalid("Enter an existing GitHub branch name.")
        }
    }
}
