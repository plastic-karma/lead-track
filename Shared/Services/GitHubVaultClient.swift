import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// An optional transport; local persistence and merge policy belong to the sync coordinator.
actor GitHubVaultClient: VaultRemote {
    private let configuration: VaultConfiguration
    private let token: String
    private let session: URLSession
    private var operationInProgress = false
    private var cachedIndex: GitHubVaultIndex?
    private var blobs: [String: Data] = [:]

    init(configuration: VaultConfiguration, token: String, session: URLSession = .shared) {
        self.configuration = configuration
        self.token = token
        self.session = session
    }

    func fetch(cached: [String: VaultRemoteFile]) async throws -> VaultRemoteSnapshot {
        let api = try beginOperation()
        defer { operationInProgress = false }
        let head = try await api.head()
        let index = try await repositoryIndex(rootSHA: head.tree.sha, api: api)
        let files = try await readFiles(index.candidates, cached: cached, api: api)
        blobs = files.values.reduce(into: [:]) { $0[$1.sha] = $1.data }
        return VaultRemoteSnapshot(headSHA: head.sha, treeSHA: head.tree.sha, files: files)
    }

    func commit(changes: [VaultFileChange], onto snapshot: VaultRemoteSnapshot) async throws -> String {
        let api = try beginOperation()
        defer { operationInProgress = false }
        try GitHubVaultLimits.validateSHA(snapshot.headSHA)
        try GitHubVaultLimits.validateSHA(snapshot.treeSHA)
        let head = try await api.head()
        guard head.sha == snapshot.headSHA, head.tree.sha == snapshot.treeSHA else {
            throw VaultError.conflict("The GitHub branch changed. Sync again to merge the remote changes.")
        }
        let index = try await repositoryIndex(rootSHA: head.tree.sha, api: api)
        try index.validate(changes, snapshot: snapshot)
        let effective = changes.filter { $0.data != snapshot.files[$0.path]?.data }
        guard !effective.isEmpty else { return head.sha }
        // expectedHeadOid is checked by GitHub in the same mutation that publishes every file.
        let newCommit = try await api.createCommit(changes: effective, expectedHead: snapshot.headSHA)
        cachedIndex = nil
        return newCommit
    }

    private func beginOperation() throws -> GitHubVaultAPI {
        try Task.checkCancellation()
        guard !operationInProgress else {
            throw VaultError.conflict("A GitHub vault operation is already running. Wait for it to finish.")
        }
        let validated = try configuration.validated()
        guard validated.folder.split(separator: "/").count <= GitHubVaultLimits.depth else {
            throw VaultError.invalid("The selected vault folder exceeds the 32-level sync limit.")
        }
        guard !token.isEmpty, token.utf8.allSatisfy({ (33 ... 126).contains($0) }) else {
            throw VaultError.invalid("Enter a valid GitHub personal access token.")
        }
        operationInProgress = true
        return GitHubVaultAPI(configuration: validated, token: token, session: session)
    }

    private func repositoryIndex(rootSHA: String, api: GitHubVaultAPI) async throws -> GitHubVaultIndex {
        if let cachedIndex, cachedIndex.rootSHA == rootSHA { return cachedIndex }
        let index = try await GitHubVaultRepository(api: api).index(rootSHA: rootSHA)
        cachedIndex = index
        return index
    }

    private func readFiles(
        _ entries: [GitHubVaultEntry],
        cached: [String: VaultRemoteFile],
        api: GitHubVaultAPI
    ) async throws -> [String: VaultRemoteFile] {
        var supplied: [String: Data] = [:]
        for file in cached.values {
            supplied[file.sha] = file.data
        }
        var loaded: [String: Data] = [:]
        var files: [String: VaultRemoteFile] = [:]
        for entry in entries {
            try Task.checkCancellation()
            let data: Data
            if let existing = loaded[entry.sha] ?? blobs[entry.sha] ?? supplied[entry.sha],
               existing.count == entry.size
            {
                data = existing
            } else {
                let blob: GitHubVaultBlob = try await api.send(["blobs", entry.sha])
                data = try blob.decoded(expectedSHA: entry.sha)
                guard data.count == entry.size else {
                    throw VaultError.remote("GitHub returned blob content that does not match the complete vault tree.")
                }
            }
            loaded[entry.sha] = data
            files[entry.path] = VaultRemoteFile(sha: entry.sha, data: data)
        }
        return files
    }
}
