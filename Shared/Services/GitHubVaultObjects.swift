import Foundation

nonisolated struct GitHubVaultObject: Codable {
    let sha: String
}

nonisolated struct GitHubVaultReference: Decodable {
    let ref: String
    let object: Target

    struct Target: Decodable {
        let type: String
        let sha: String
    }
}

nonisolated struct GitHubVaultCommit: Decodable {
    let sha: String
    let tree: GitHubVaultObject
}

nonisolated struct GitHubVaultTree: Decodable {
    let sha: String
    let truncated: Bool
    let tree: [GitHubVaultEntry]
}

nonisolated struct GitHubVaultEntry: Decodable {
    let path: String
    let mode: String
    let type: String
    let sha: String
    let size: Int?

    var isDirectory: Bool {
        type == "tree" && mode == "040000"
    }

    var isFile: Bool {
        type == "blob" && (mode == "100644" || mode == "100755")
    }
}

nonisolated struct GitHubVaultBlob: Decodable {
    let sha: String
    let encoding: String
    let content: String
    let size: Int

    func decoded(expectedSHA: String) throws -> Data {
        guard sha == expectedSHA, encoding == "base64", size >= 0,
              size <= GitHubVaultLimits.blobBytes
        else {
            throw VaultError.remote("GitHub returned an invalid or oversized vault blob.")
        }
        let compact = content.filter { $0 != "\n" && $0 != "\r" }
        guard let data = Data(base64Encoded: compact), data.count == size else {
            throw VaultError.remote("GitHub returned invalid Base64 vault content; no files were applied.")
        }
        return data
    }
}

nonisolated struct GitHubVaultCommitMutation: Encodable {
    let query = """
    mutation LeadStoneVaultCommit($input: CreateCommitOnBranchInput!) {
      createCommitOnBranch(input: $input) { commit { oid } }
    }
    """
    let variables: Variables

    struct Variables: Encodable {
        let input: Input
    }

    struct Input: Encodable {
        let branch: Branch
        let expectedHeadOid: String
        let message = Message()
        let fileChanges: FileChanges
    }

    struct Branch: Encodable {
        let repositoryNameWithOwner: String
        let branchName: String
    }

    struct Message: Encodable {
        let headline = "Sync LeadStone vault"
    }

    struct Addition: Encodable {
        let path: String
        let contents: String
    }

    struct Deletion: Encodable {
        let path: String
    }

    struct FileChanges: Encodable {
        var additions: [Addition] = []
        var deletions: [Deletion] = []
    }

    init(configuration: VaultConfiguration, changes: [VaultFileChange], expectedHead: String) {
        var files = FileChanges()
        for change in changes {
            let path = "\(configuration.folder)/\(change.path)"
            if let data = change.data {
                files.additions.append(Addition(path: path, contents: data.base64EncodedString()))
            } else {
                files.deletions.append(Deletion(path: path))
            }
        }
        variables = Variables(input: Input(
            branch: Branch(
                repositoryNameWithOwner: "\(configuration.owner)/\(configuration.repository)",
                branchName: configuration.branch
            ),
            expectedHeadOid: expectedHead,
            fileChanges: files
        ))
    }
}

nonisolated struct GitHubVaultCommitResult: Decodable {
    let data: Payload?
    let errors: [Failure]?

    struct Payload: Decodable {
        let createCommitOnBranch: Publication?
    }

    struct Publication: Decodable {
        let commit: Commit?
    }

    struct Commit: Decodable {
        let oid: String
    }

    /// Never retain or surface the server message, which may contain private content.
    struct Failure: Decodable {
        let type: String?
    }

    func commitOID() throws -> String {
        if let errors, !errors.isEmpty {
            if errors.contains(where: { $0.type == "STALE_DATA" }) {
                throw VaultError.conflict("The GitHub branch changed. Sync again to merge the remote changes.")
            }
            throw VaultError.remote(
                "GitHub rejected the atomic vault commit. Check Contents read/write permission, branch rules, and rate limits; sync again."
            )
        }
        guard let oid = data?.createCommitOnBranch?.commit?.oid else {
            throw VaultError.remote("GitHub did not acknowledge the vault commit. Sync again to reconcile the branch.")
        }
        try GitHubVaultLimits.validateSHA(oid)
        return oid
    }
}

nonisolated enum GitHubVaultLimits {
    static let blobBytes = 25 * 1024 * 1024
    // Application safety bounds, not a guarantee that GitHub accepts every request below them.
    static let uploadBytes = 25 * 1024 * 1024
    static let uploadRequestBytes = 40 * 1024 * 1024
    static let snapshotBytes = 128 * 1024 * 1024
    static let responseBytes = 40 * 1024 * 1024
    static let entries = 10000
    static let depth = 32

    static func validateSHA(_ sha: String) throws {
        guard sha.utf8.count == 40, sha.utf8.allSatisfy({
            (48 ... 57).contains($0) || (97 ... 102).contains($0)
        }) else {
            throw VaultError.remote("GitHub returned an invalid Git object identifier.")
        }
    }
}
