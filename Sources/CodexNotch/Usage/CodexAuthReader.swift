import Foundation

struct CodexCredentials: Equatable, Sendable {
    let accessToken: String
    let accountID: String?
}

enum CodexAuthError: Error, Equatable {
    case authFileUnavailable
    case invalidAuthFormat
    case missingAccessToken
}

protocol CredentialsReading: Sendable {
    func read() throws -> CodexCredentials
}

struct CodexAuthReader: CredentialsReading {
    let rootDirectory: URL

    init(environment: [String: String] = ProcessInfo.processInfo.environment,
         homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.rootDirectory = environment["CODEX_HOME"].map { URL(fileURLWithPath: $0) }
            ?? homeDirectory.appendingPathComponent(".codex", isDirectory: true)
    }

    /// Reads credentials from a specific account home instead of the process
    /// environment, which stays pointed at the account CodexNotch itself sees.
    init(codexHome: URL) {
        self.rootDirectory = codexHome
    }

    func read() throws -> CodexCredentials {
        let authURL = rootDirectory.appendingPathComponent("auth.json")
        let data: Data
        do {
            data = try Data(contentsOf: authURL)
        } catch {
            throw CodexAuthError.authFileUnavailable
        }
        return try Self.credentials(from: data)
    }

    static func credentials(from data: Data) throws -> CodexCredentials {
        do {
            let dto = try JSONDecoder().decode(AuthDTO.self, from: data)
            guard !dto.tokens.accessToken.isEmpty else {
                throw CodexAuthError.missingAccessToken
            }
            return CodexCredentials(
                accessToken: dto.tokens.accessToken,
                accountID: dto.tokens.accountID
            )
        } catch let error as CodexAuthError {
            throw error
        } catch {
            throw CodexAuthError.invalidAuthFormat
        }
    }
}

private struct AuthDTO: Decodable {
    let tokens: TokenDTO

    struct TokenDTO: Decodable {
        let accessToken: String
        let accountID: String?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case accountID = "account_id"
        }
    }
}
