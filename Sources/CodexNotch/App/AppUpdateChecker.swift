import Foundation

struct AppVersion: Comparable, Equatable, CustomStringConvertible {
    let major: Int
    let minor: Int
    let patch: Int

    init?(rawValue: String) {
        var normalized = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.hasPrefix("v") || normalized.hasPrefix("V") {
            normalized.removeFirst()
        }

        normalized = normalized
            .split(separator: "+", maxSplits: 1, omittingEmptySubsequences: true)
            .first
            .map(String.init) ?? ""
        normalized = normalized
            .split(separator: "-", maxSplits: 1, omittingEmptySubsequences: true)
            .first
            .map(String.init) ?? ""

        let components = normalized.split(separator: ".", omittingEmptySubsequences: false)
        guard components.count == 3,
              components.allSatisfy({ component in
                  !component.isEmpty
                      && component.allSatisfy { character in
                          character >= "0" && character <= "9"
                      }
                      && (component == "0" || !component.hasPrefix("0"))
              }),
              let major = Int(components[0]),
              let minor = Int(components[1]),
              let patch = Int(components[2]) else {
            return nil
        }

        self.major = major
        self.minor = minor
        self.patch = patch
    }

    init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    static let zero = AppVersion(major: 0, minor: 0, patch: 0)

    static func fromBundle(_ bundle: Bundle = .main) -> AppVersion? {
        guard let rawValue = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else {
            return nil
        }
        return AppVersion(rawValue: rawValue)
    }

    var description: String {
        "\(major).\(minor).\(patch)"
    }

    var displayValue: String {
        "v\(description)"
    }

    static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }
}

struct UpdateRelease: Equatable {
    let version: AppVersion
    let url: URL
}

enum UpdateCheckResult: Equatable {
    case upToDate(current: AppVersion)
    case updateAvailable(current: AppVersion, release: UpdateRelease)
}

enum AppUpdateError: Error, Equatable {
    case network
    case invalidHTTPResponse
    case httpStatus(Int)
    case decodingFailed
    case invalidReleaseMetadata
}

struct AppUpdateChecker {
    static let defaultEndpoint = URL(
        string: "https://api.github.com/repos/fengdwx/codex-notch/releases/latest"
    )!

    let currentVersion: AppVersion
    let session: URLSession
    let endpoint: URL

    init(
        currentVersion: AppVersion? = AppVersion.fromBundle() ?? .zero,
        session: URLSession = .shared,
        endpoint: URL = AppUpdateChecker.defaultEndpoint
    ) {
        self.currentVersion = currentVersion ?? .zero
        self.session = session
        self.endpoint = endpoint
    }

    func check() async throws -> UpdateCheckResult {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("CodexNotch/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AppUpdateError.network
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppUpdateError.invalidHTTPResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw AppUpdateError.httpStatus(httpResponse.statusCode)
        }

        let release: GitHubReleaseDTO
        do {
            release = try JSONDecoder().decode(GitHubReleaseDTO.self, from: data)
        } catch {
            throw AppUpdateError.decodingFailed
        }

        guard !release.draft,
              !release.prerelease,
              let version = AppVersion(rawValue: release.tagName),
              let url = URL(string: release.htmlURL),
              url.scheme == "https",
              url.host?.lowercased() == "github.com",
              !release.htmlURL.isEmpty else {
            throw AppUpdateError.invalidReleaseMetadata
        }

        let update = UpdateRelease(version: version, url: url)
        guard version > currentVersion else {
            return .upToDate(current: currentVersion)
        }
        return .updateAvailable(current: currentVersion, release: update)
    }
}

private struct GitHubReleaseDTO: Decodable {
    let tagName: String
    let htmlURL: String
    let draft: Bool
    let prerelease: Bool

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case draft
        case prerelease
    }
}
