import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

nonisolated struct GitHubVaultAPI {
    let configuration: VaultConfiguration
    let token: String
    let session: URLSession

    func head() async throws -> GitHubVaultCommit {
        let reference: GitHubVaultReference = try await send(branchEndpoint("ref"))
        try validate(reference)
        let commit: GitHubVaultCommit = try await send(["commits", reference.object.sha])
        guard commit.sha == reference.object.sha else {
            throw VaultError.remote("GitHub returned a different branch commit.")
        }
        try GitHubVaultLimits.validateSHA(commit.tree.sha)
        return commit
    }

    func createCommit(changes: [VaultFileChange], expectedHead: String) async throws -> String {
        let mutation = GitHubVaultCommitMutation(
            configuration: configuration, changes: changes, expectedHead: expectedHead
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = .withoutEscapingSlashes
        let body = try encoder.encode(mutation)
        guard body.count <= GitHubVaultLimits.uploadRequestBytes else {
            throw VaultError
                .invalid("The atomic vault upload exceeds the 40 MiB JSON request limit. No files were published.")
        }
        let request = try request(["graphql"], method: "POST", body: body, recursive: false)
        let response: GitHubVaultCommitResult = try await decode(request, endpoint: ["graphql"])
        return try response.commitOID()
    }

    func send<Response: Decodable>(_ endpoint: [String], recursive: Bool = false) async throws -> Response {
        let path = ["repos", configuration.owner, configuration.repository, "git"] + endpoint
        let request = try request(path, method: "GET", body: nil, recursive: recursive)
        return try await decode(request, endpoint: endpoint)
    }

    private func decode<Response: Decodable>(_ request: URLRequest, endpoint: [String]) async throws -> Response {
        try Task.checkCancellation()
        let (data, response) = try await receive(request)
        try Task.checkCancellation()
        guard let response = response as? HTTPURLResponse, response.url == request.url else {
            throw VaultError.remote("GitHub returned an unexpected response destination.")
        }
        try checkStatus(response.statusCode, endpoint: endpoint)
        guard data.count <= GitHubVaultLimits.responseBytes else {
            throw VaultError.remote("The GitHub response exceeds the 40 MiB safety limit.")
        }
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw VaultError.remote("GitHub returned malformed vault metadata; no partial snapshot was accepted.")
        }
    }

    private func receive(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            #if canImport(FoundationNetworking)
            // corelibs Foundation has no AsyncBytes; enforce the retained-body bound after receiving.
            return try await session.data(for: request, delegate: GitHubVaultRedirectGuard())
            #else
            let (bytes, response) = try await session.bytes(for: request, delegate: GitHubVaultRedirectGuard())
            defer { bytes.task.cancel() }
            guard response.expectedContentLength <= Int64(GitHubVaultLimits.responseBytes) else {
                throw VaultError.remote("The GitHub response exceeds the 40 MiB safety limit.")
            }
            var data = Data()
            if response.expectedContentLength > 0 { data.reserveCapacity(Int(response.expectedContentLength)) }
            for try await byte in bytes {
                guard data.count < GitHubVaultLimits.responseBytes else {
                    throw VaultError.remote("The GitHub response exceeds the 40 MiB safety limit.")
                }
                data.append(byte)
            }
            return (data, response)
            #endif
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as VaultError {
            throw error
        } catch {
            if Task.isCancelled || (error as? URLError)?.code == .cancelled {
                throw CancellationError()
            }
            throw VaultError.remote("Could not contact GitHub securely. Check the connection and try syncing again.")
        }
    }

    private func request(
        _ path: [String],
        method: String,
        body: Data?,
        recursive: Bool
    ) throws -> URLRequest {
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/%?#"))
        let encoded = try path.map { component -> String in
            guard let value = component.addingPercentEncoding(withAllowedCharacters: allowed) else {
                throw VaultError.invalid("The GitHub destination contains an invalid URL component.")
            }
            return value
        }
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.github.com"
        components.percentEncodedPath = "/" + encoded.joined(separator: "/")
        if recursive { components.queryItems = [URLQueryItem(name: "recursive", value: "1")] }
        guard let url = components.url else { throw VaultError.invalid("Invalid GitHub destination.") }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 60)
        request.httpMethod = method
        request.httpBody = body
        request.httpShouldHandleCookies = false
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("LeadStone", forHTTPHeaderField: "User-Agent")
        if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        return request
    }

    private func branchEndpoint(_ action: String) -> [String] {
        [action, "heads"] + configuration.branch.split(separator: "/").map(String.init)
    }

    private func validate(_ reference: GitHubVaultReference) throws {
        guard reference.ref == "refs/heads/\(configuration.branch)", reference.object.type == "commit" else {
            throw VaultError.remote("GitHub returned a different branch reference.")
        }
        try GitHubVaultLimits.validateSHA(reference.object.sha)
    }

    private func checkStatus(_ status: Int, endpoint: [String]) throws {
        guard !(200 ... 299).contains(status) else { return }
        if endpoint.first == "ref", [404, 409].contains(status) {
            throw VaultError
                .remote(
                    "The selected branch is missing, empty, or inaccessible. Initialize it with a commit and check token access."
                )
        }
        switch status {
        case 401:
            throw VaultError.remote("GitHub rejected the token. Reconnect with a valid personal access token.")
        case 403:
            throw VaultError
                .remote(
                    "GitHub denied access or rate-limited sync. Check repository Contents read/write permission and try later."
                )
        case 404:
            throw VaultError
                .remote("GitHub could not find the repository or Git object. Check the destination and token access.")
        case 429:
            throw VaultError.remote("GitHub rate-limited sync. Wait before syncing again.")
        case 300 ... 399:
            throw VaultError
                .remote(
                    "GitHub redirected the request. Update the repository destination; credentials were not forwarded."
                )
        default:
            throw VaultError
                .remote("GitHub request failed (HTTP \(status)). No remote file content was applied locally.")
        }
    }
}

/// Reject even same-host redirects: a moved repository must be selected explicitly.
final class GitHubVaultRedirectGuard: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _: URLSession,
        task _: URLSessionTask,
        willPerformHTTPRedirection _: HTTPURLResponse,
        newRequest _: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}
