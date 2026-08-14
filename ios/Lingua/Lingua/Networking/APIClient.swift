//  APIClient.swift
//  Networking layer — talks to FastAPI backend.
//  Per Decision #28: Bearer auth, /api/v1/ prefix.
//  Per Decision #9: machine-readable error codes, health endpoint (no auth).
//  Per Decision #30: lazy TTS handled server-side.

import Foundation

// MARK: - Configuration

enum APIConfig {
    static let baseURL = "http://100.66.129.43:5051/api/v1"
    static let healthURL = "http://100.66.129.43:5051/api/v1/health"
    static let timeout: TimeInterval = 30
}

// MARK: - API Error

struct APIError: Error, LocalizedError {
    let code: String
    let message: String
    let httpStatus: Int

    var errorDescription: String? { message }

    static let unauthorized = APIError(code: "UNAUTHORIZED", message: "Authentication failed — check API key in Settings", httpStatus: 401)
    static let offline = APIError(code: "OFFLINE", message: "Can't reach Idoru Lingua server. Check that Tailscale is connected.", httpStatus: 0)
}

// MARK: - API Client

@MainActor
final class APIClient: ObservableObject {
    static let shared = APIClient()

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = APIConfig.timeout
        config.timeoutIntervalForResource = APIConfig.timeout
        config.waitsForConnectivity = false
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    private func getAPIKey() -> String {
        UserDefaults.standard.string(forKey: "lingua_api_key") ?? ""
    }

    private func makeRequest(method: String, path: String, body: Data? = nil) throws -> URLRequest {
        guard let url = URL(string: "\(APIConfig.baseURL)\(path)") else {
            throw APIError(code: "INTERNAL_ERROR", message: "Invalid URL", httpStatus: 0)
        }

        var request = URLRequest(url: url, timeoutInterval: APIConfig.timeout)
        request.httpMethod = method
        request.setValue("Bearer \(getAPIKey())", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body {
            request.httpBody = body
        }

        return request
    }

    private func handleResponse<T: Decodable>(_ data: Data, _ response: URLResponse) throws -> T {
        guard let http = response as? HTTPURLResponse else {
            throw APIError(code: "INTERNAL_ERROR", message: "Invalid response", httpStatus: 0)
        }

        if http.statusCode == 401 {
            throw APIError.unauthorized
        }

        guard (200...299).contains(http.statusCode) else {
            // Try to parse error response
            if let errorBody = try? decoder.decode(ErrorResponse.self, from: data) {
                throw APIError(code: errorBody.code, message: errorBody.error, httpStatus: http.statusCode)
            }
            throw APIError(code: "HTTP_ERROR", message: "Server error (\(http.statusCode))", httpStatus: http.statusCode)
        }

        return try decoder.decode(T.self, from: data)
    }

    // MARK: - Health (no auth)

    struct HealthResponse: Decodable {
        let status: String
        let version: String
        let azureStatus: String

        enum CodingKeys: String, CodingKey {
            case status, version
            case azureStatus = "azure_status"
        }
    }

    func health() async throws -> HealthResponse {
        guard let url = URL(string: APIConfig.healthURL) else {
            throw APIError(code: "INTERNAL_ERROR", message: "Invalid URL", httpStatus: 0)
        }

        var request = URLRequest(url: url, timeoutInterval: 10)
        request.httpMethod = "GET"

        do {
            let (data, response) = try await session.data(for: request)
            return try handleResponse(data, response)
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.offline
        }
    }

    // MARK: - Session

    struct DueCardsResponse: Decodable {
        let cards: [Card]
    }

    func getDueCards() async throws -> [Card] {
        let request = try makeRequest(method: "GET", path: "/session/due")
        let (data, response) = try await session.data(for: request)
        return try handleResponse<DueCardsResponse>(data, response).cards
    }

    struct StartSessionRequest: Encodable {
        let cardIds: [Int]?
        let source: String

        enum CodingKeys: String, CodingKey {
            case cardIds = "card_ids"
            case source
        }
    }

    struct StartSessionResponse: Decodable {
        let sessionId: String
        let totalCards: Int
        let firstCard: Card?

        enum CodingKeys: String, CodingKey {
            case sessionId = "session_id"
            case totalCards = "total_cards"
            case firstCard = "first_card"
        }
    }

    func startSession(cardIds: [Int]? = nil, source: String = "on_demand") async throws -> StartSessionResponse {
        let body = try encoder.encode(StartSessionRequest(cardIds: cardIds, source: source))
        let request = try makeRequest(method: "POST", path: "/session/start", body: body)
        let (data, response) = try await session.data(for: request)
        return try handleResponse(data, response)
    }

    struct ActiveSessionResponse: Decodable {
        let session: SessionInfo?
        let currentCard: Card?
    }

    func getActiveSession() async throws -> ActiveSessionResponse {
        let request = try makeRequest(method: "GET", path: "/session/active")
        let (data, response) = try await session.data(for: request)
        return try handleResponse(data, response)
    }

    // MARK: - Submit answers

    struct TextSubmitRequest: Encodable {
        let answer: String
    }

    struct SubmitResponse: Decodable {
        let cardId: Int
        let grade: String
        let nextInterval: String
        let correctOption: Int?
        let pronunciation: PronunciationScore?
        let nextCard: Card?

        enum CodingKeys: String, CodingKey {
            case cardId = "card_id"
            case grade
            case nextInterval = "next_interval"
            case correctOption = "correct_option"
            case pronunciation
            case nextCard = "next_card"
        }
    }

    func submitText(sessionId: String, answer: String) async throws -> SubmitResponse {
        let body = try encoder.encode(TextSubmitRequest(answer: answer))
        let request = try makeRequest(method: "POST", path: "/session/\(sessionId)/submit/text", body: body)
        let (data, response) = try await session.data(for: request)
        return try handleResponse(data, response)
    }

    struct MCSubmitRequest: Encodable {
        let selectedOption: Int

        enum CodingKeys: String, CodingKey {
            case selectedOption = "selected_option"
        }
    }

    func submitMC(sessionId: String, selectedOption: Int) async throws -> SubmitResponse {
        let body = try encoder.encode(MCSubmitRequest(selectedOption: selectedOption))
        let request = try makeRequest(method: "POST", path: "/session/\(sessionId)/submit/mc", body: body)
        let (data, response) = try await session.data(for: request)
        return try handleResponse(data, response)
    }

    func skipCard(sessionId: String) async throws -> SubmitResponse {
        let request = try makeRequest(method: "POST", path: "/session/\(sessionId)/skip")
        let (data, response) = try await session.data(for: request)
        return try handleResponse(data, response)
    }

    func undoRating(sessionId: String) async throws -> UndoResponse {
        let request = try makeRequest(method: "POST", path: "/session/\(sessionId)/undo")
        let (data, response) = try await session.data(for: request)
        return try handleResponse(data, response)
    }

    struct UndoResponse: Decodable {
        let undone: Bool
    }

    struct SessionSummary: Decodable {
        let sessionId: String
        let cardsCompleted: Int
        let totalCards: Int
        let again: Int
        let hard: Int
        let good: Int
        let easy: Int

        enum CodingKeys: String, CodingKey {
            case sessionId = "session_id"
            case cardsCompleted = "cards_completed"
            case totalCards = "total_cards"
            case again, hard, good, easy
        }
    }

    func endSession(sessionId: String) async throws -> SessionSummary {
        let request = try makeRequest(method: "POST", path: "/session/\(sessionId)/end")
        let (data, response) = try await session.data(for: request)
        return try handleResponse(data, response)
    }

    // MARK: - Card interaction

    func getCardAudio(cardId: Int) async throws -> URL {
        let request = try makeRequest(method: "GET", path: "/card/\(cardId)/audio")
        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError(code: "AUDIO_UNAVAILABLE", message: "Audio not available", httpStatus: 0)
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("lingua_card_\(cardId).m4a")
        try data.write(to: tempURL)
        return tempURL
    }

    struct ExplainResponse: Decodable {
        let cardId: Int
        let grammarNote: String?

        enum CodingKeys: String, CodingKey {
            case cardId = "card_id"
            case grammarNote = "grammar_note"
        }
    }

    func getCardExplanation(cardId: Int) async throws -> String? {
        let request = try makeRequest(method: "GET", path: "/card/\(cardId)/explain")
        let (data, response) = try await session.data(for: request)
        return try handleResponse<ExplainResponse>(data, response).grammarNote
    }

    // MARK: - Progress

    struct ProgressOverviewResponse: Decodable {
        let cities: [CityProgress]
    }

    func getProgressOverview() async throws -> [CityProgress] {
        let request = try makeRequest(method: "GET", path: "/progress/overview")
        let (data, response) = try await session.data(for: request)
        return try handleResponse<ProgressOverviewResponse>(data, response).cities
    }

    struct ClustersResponse: Decodable {
        let cityId: Int
        let clusters: [ClusterStrength]
    }

    func getClusterStrength(cityId: Int) async throws -> [ClusterStrength] {
        let request = try makeRequest(method: "GET", path: "/progress/clusters/\(cityId)")
        let (data, response) = try await session.data(for: request)
        return try handleResponse<ClustersResponse>(data, response).clusters
    }

    // MARK: - Stats

    struct RetentionResponse: Decodable {
        let data: [RetentionPoint]
    }

    func getRetention(days: Int = 30) async throws -> [RetentionPoint] {
        let request = try makeRequest(method: "GET", path: "/stats/retention?range=\(days)")
        let (data, response) = try await session.data(for: request)
        return try handleResponse<RetentionResponse>(data, response).data
    }

    struct HistoryResponse: Decodable {
        let data: [RetentionPoint]
    }

    func getHistory(days: Int = 30) async throws -> [RetentionPoint] {
        let request = try makeRequest(method: "GET", path: "/stats/history?range=\(days)")
        let (data, response) = try await session.data(for: request)
        return try handleResponse<HistoryResponse>(data, response).data
    }

    struct LeechesResponse: Decodable {
        let leeches: [LeechCard]
    }

    func getLeeches() async throws -> [LeechCard] {
        let request = try makeRequest(method: "GET", path: "/stats/leeches")
        let (data, response) = try await session.data(for: request)
        return try handleResponse<LeechesResponse>(data, response).leeches
    }

    // MARK: - Practice

    func getPracticeQuiz() async throws -> [Card] {
        let request = try makeRequest(method: "GET", path: "/practice/quiz")
        let (data, response) = try await session.data(for: request)
        return try handleResponse<DueCardsResponse>(data, response).cards
    }

    struct FreePracticeResponse: Decodable {
        let cards: [Card]
    }

    func getFreePractice(cityId: Int) async throws -> [Card] {
        let request = try makeRequest(method: "GET", path: "/practice/free/\(cityId)")
        let (data, response) = try await session.data(for: request)
        return try handleResponse<FreePracticeResponse>(data, response).cards
    }

    // MARK: - Settings

    func getSettings() async throws -> ServerSettings {
        let request = try makeRequest(method: "GET", path: "/settings")
        let (data, response) = try await session.data(for: request)
        return try handleResponse(data, response)
    }

    func updateSettings(_ updates: [String: AnyCodable]) async throws -> ServerSettings {
        let body = try encoder.encode(updates)
        let request = try makeRequest(method: "PATCH", path: "/settings", body: body)
        let (data, response) = try await session.data(for: request)
        return try handleResponse(data, response)
    }
}

// MARK: - Error response

struct ErrorResponse: Decodable {
    let error: String
    let code: String
}