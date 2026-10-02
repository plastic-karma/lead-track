import Foundation

nonisolated struct GitHubVaultIndex {
    let rootSHA: String
    let entries: [String: GitHubVaultEntry]
    let foldedPaths: [String: String]
    let candidates: [GitHubVaultEntry]

    func validate(_ changes: [VaultFileChange], snapshot: VaultRemoteSnapshot) throws {
        guard changes.count <= GitHubVaultLimits.entries else {
            throw VaultError.invalid("A vault sync cannot change more than 10,000 files at once.")
        }
        var changedPaths = Set<String>()
        var byteCount = 0
        for change in changes {
            try GitHubVaultPaths.validateManaged(change.path)
            guard changedPaths.insert(GitHubVaultPaths.fold(change.path)).inserted else {
                throw VaultError.invalid("Vault changes contain duplicate or case-colliding paths.")
            }
            let count = change.data?.count ?? 0
            guard count <= GitHubVaultLimits.blobBytes else {
                throw VaultError.invalid("A vault file exceeds the 25 MiB sync limit.")
            }
            byteCount += count
            guard byteCount <= GitHubVaultLimits.uploadBytes else {
                throw VaultError.invalid("An atomic vault upload exceeds the 25 MiB total file-content limit.")
            }
            try validateDestination(change.path, snapshot: snapshot)
        }
        for change in changes {
            guard GitHubVaultPaths.parents(change.path).allSatisfy({
                !changedPaths.contains(GitHubVaultPaths.fold($0))
            }) else {
                throw VaultError.invalid("A vault change would replace another changed file's parent folder.")
            }
        }
        try validateResultSize(changes)
    }

    private func validateDestination(_ path: String, snapshot: VaultRemoteSnapshot) throws {
        try validateSpelling(path)
        if let existing = entries[path] {
            guard existing.isFile, snapshot.files[path]?.sha == existing.sha else {
                throw VaultError.conflict("A vault write would replace a folder or an unacknowledged file: \(path)")
            }
        } else if snapshot.files[path] != nil {
            throw VaultError.conflict("The vault snapshot no longer matches its Git tree. Sync again.")
        }
        for parent in GitHubVaultPaths.parents(path) {
            try validateSpelling(parent)
            guard entries[parent] == nil || entries[parent]?.isDirectory == true else {
                throw VaultError.conflict("A vault write would replace an existing file with a folder: \(parent)")
            }
        }
    }

    private func validateResultSize(_ changes: [VaultFileChange]) throws {
        var paths = Set(entries.keys)
        var byteCount = candidates.reduce(0) { $0 + ($1.size ?? 0) }
        for change in changes {
            byteCount += (change.data?.count ?? 0) - (entries[change.path]?.size ?? 0)
            if change.data == nil {
                paths.remove(change.path)
            } else {
                paths.insert(change.path)
                paths.formUnion(GitHubVaultPaths.parents(change.path))
            }
        }
        guard byteCount <= GitHubVaultLimits.snapshotBytes, paths.count <= GitHubVaultLimits.entries else {
            throw VaultError.invalid("The resulting vault exceeds the 128 MiB or 10,000-entry sync limit.")
        }
    }

    private func validateSpelling(_ path: String) throws {
        guard let existing = foldedPaths[GitHubVaultPaths.fold(path)] else { return }
        guard existing == path else {
            throw VaultError.conflict("Vault paths collide by case or Unicode spelling: \(existing) and \(path)")
        }
    }
}

nonisolated struct GitHubVaultRepository {
    let api: GitHubVaultAPI

    func index(rootSHA: String) async throws -> GitHubVaultIndex {
        guard let subtree = try await directorySHA(rootSHA: rootSHA) else {
            return GitHubVaultIndex(rootSHA: rootSHA, entries: [:], foldedPaths: [:], candidates: [])
        }
        let tree = try await readTree(subtree, recursive: true)
        var entries: [String: GitHubVaultEntry] = [:]
        var foldedPaths: [String: String] = [:]
        var candidates: [GitHubVaultEntry] = []
        var byteCount = 0
        for entry in tree.tree {
            try Task.checkCancellation()
            try GitHubVaultPaths.validateEntry(entry)
            let folded = GitHubVaultPaths.fold(entry.path)
            guard foldedPaths.updateValue(entry.path, forKey: folded) == nil else {
                throw VaultError.remote("The vault contains duplicate or case-colliding Git paths.")
            }
            entries[entry.path] = entry
            if !entry.isDirectory, GitHubVaultPaths.isCandidate(entry.path) {
                try validateCandidate(entry, byteCount: &byteCount)
                candidates.append(entry)
            }
        }
        try validateParents(entries)
        return GitHubVaultIndex(rootSHA: rootSHA, entries: entries, foldedPaths: foldedPaths, candidates: candidates)
    }

    private func directorySHA(rootSHA: String) async throws -> String? {
        var current = rootSHA
        for component in api.configuration.folder.split(separator: "/").map(String.init) {
            let tree = try await readTree(current)
            let matches = tree.tree.filter { GitHubVaultPaths.fold($0.path) == GitHubVaultPaths.fold(component) }
            guard !matches.isEmpty else { return nil }
            guard matches.count == 1, let entry = matches.first,
                  entry.path == component, entry.isDirectory
            else {
                throw VaultError
                    .conflict("The selected vault folder collides with an existing file or differently spelled folder.")
            }
            try GitHubVaultLimits.validateSHA(entry.sha)
            current = entry.sha
        }
        return current
    }

    private func readTree(_ sha: String, recursive: Bool = false) async throws -> GitHubVaultTree {
        try GitHubVaultLimits.validateSHA(sha)
        let tree: GitHubVaultTree = try await api.send(["trees", sha], recursive: recursive)
        guard tree.sha == sha, !tree.truncated else {
            throw VaultError
                .remote(
                    "GitHub returned an incomplete vault tree. Choose a smaller folder; no deletions were inferred."
                )
        }
        guard tree.tree.count <= GitHubVaultLimits.entries else {
            throw VaultError
                .remote("The selected Git tree exceeds the 10,000-entry sync limit. Choose a smaller vault folder.")
        }
        return tree
    }

    private func validateCandidate(_ entry: GitHubVaultEntry, byteCount: inout Int) throws {
        try GitHubVaultPaths.validateManaged(entry.path)
        guard entry.isFile else {
            throw VaultError
                .remote("A managed vault path is a symbolic link or submodule, not a regular file: \(entry.path)")
        }
        guard let size = entry.size, size >= 0, size <= GitHubVaultLimits.blobBytes else {
            throw VaultError.remote("A vault file has an invalid size or exceeds the 25 MiB sync limit: \(entry.path)")
        }
        byteCount += size
        guard byteCount <= GitHubVaultLimits.snapshotBytes else {
            throw VaultError.remote("The selected vault files exceed the 128 MiB sync limit. Choose a smaller folder.")
        }
    }

    private func validateParents(_ entries: [String: GitHubVaultEntry]) throws {
        for path in entries.keys {
            for parent in GitHubVaultPaths.parents(path) {
                guard entries[parent]?.isDirectory == true else {
                    throw VaultError.remote("GitHub returned an incomplete or unsafe vault folder hierarchy.")
                }
            }
        }
    }
}

nonisolated enum GitHubVaultPaths {
    static func fold(_ path: String) -> String {
        path.precomposedStringWithCanonicalMapping.lowercased()
    }

    static func isCandidate(_ path: String) -> Bool {
        let components = path.split(separator: "/")
        guard !components.contains(where: { [".obsidian", ".git"].contains($0.lowercased()) }) else { return false }
        let lower = path.lowercased()
        return path.hasPrefix("Attachments/") || lower.hasSuffix(".md") || lower.hasSuffix(".base")
    }

    static func validateManaged(_ path: String) throws {
        try VaultConfiguration.validatePath(path)
        guard isCandidate(path), path.split(separator: "/").count <= GitHubVaultLimits.depth else {
            throw VaultError
                .invalid("Vault files must be Markdown, Bases, or under Attachments, within 32 folder levels.")
        }
    }

    static func validateEntry(_ entry: GitHubVaultEntry) throws {
        let parts = entry.path.split(separator: "/", omittingEmptySubsequences: false)
        guard !entry.path.contains("\\"),
              !entry.path.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains),
              parts.count <= GitHubVaultLimits.depth,
              parts.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." && $0.lowercased() != ".git" })
        else {
            throw VaultError.remote("GitHub returned an unsafe vault path.")
        }
        try GitHubVaultLimits.validateSHA(entry.sha)
        let isLink = entry.type == "blob" && entry.mode == "120000"
        let isSubmodule = entry.type == "commit" && entry.mode == "160000"
        guard entry.isDirectory || entry.isFile || isLink || isSubmodule else {
            throw VaultError.remote("GitHub returned an unsupported Git tree entry.")
        }
    }

    static func parents(_ path: String) -> [String] {
        let components = path.split(separator: "/")
        guard components.count > 1 else { return [] }
        var result: [String] = []
        var current = ""
        for component in components.dropLast() {
            current = current.isEmpty ? String(component) : "\(current)/\(component)"
            result.append(current)
        }
        return result
    }
}
