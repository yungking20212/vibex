import Foundation
import Auth

public struct AIChatRequestMessage: Codable {
    public let role: String
    public let content: String
}

// Backwards-compatible alias: some files expect `NetworkAIChatService`.
public typealias NetworkAIChatService = ProductionChatService

public struct AIChatResponse: Codable {
    public let reply: String
}

public protocol AIChatService {
    func send(messages: [AIChatRequestMessage]) async throws -> String
}

public enum AIChatError: Error, LocalizedError {
    case missingToken
    case invalidResponse
    case unauthorized

    public var errorDescription: String? {
        switch self {
        case .missingToken: return "Missing access token. Please sign in again."
        case .invalidResponse: return "Invalid response from server."
        case .unauthorized: return "Your session expired. Please sign in again."
        }
    }
}

public final class ProductionChatService: AIChatService {
    private let endpoint: URL
    private let urlSession: URLSession

    public init(endpoint: URL, urlSession: URLSession = .shared) {
        self.endpoint = endpoint
        self.urlSession = urlSession
    }

    public func send(messages: [AIChatRequestMessage]) async throws -> String {
        guard let token = AuthManager.shared.session?.accessToken, !token.isEmpty else {
            print("[AI] Missing token before request")
            throw AIChatError.missingToken
        }
        print("[AI] Using token prefix: \(token.prefix(12))…")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let anon = AppConfig.supabaseAnonKey ?? ""
        if !anon.isEmpty {
            request.setValue(anon, forHTTPHeaderField: "apikey")
        }

        let body = ["messages": messages]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AIChatError.invalidResponse }

        if http.statusCode == 401 { throw AIChatError.unauthorized }
        guard 200..<300 ~= http.statusCode else { throw AIChatError.invalidResponse }

        let decoded = try JSONDecoder().decode(AIChatResponse.self, from: data)
        return decoded.reply
    }
}

