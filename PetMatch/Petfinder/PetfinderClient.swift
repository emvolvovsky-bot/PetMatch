import Foundation

actor PetfinderClient {
    private let config: PetfinderConfig
    private let session: URLSession
    private let decoder: JSONDecoder

    private var token: Token?

    init(config: PetfinderConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = decoder
    }

    func fetchAnimals(request: PetfinderAnimalsRequest) async throws -> PetfinderAnimalsResponseDTO {
        let data: PetfinderAnimalsResponseDTO = try await authedGet(path: "/animals", query: request.asQueryItems())
        return data
    }

    func fetchAnimalDetails(id: String) async throws -> PetfinderAnimalDetailsResponseDTO {
        guard let intID = Int(id) else { throw PetfinderError.invalidURL }
        let data: PetfinderAnimalDetailsResponseDTO = try await authedGet(path: "/animals/\(intID)", query: [])
        return data
    }

    // MARK: - Auth

    private func ensureValidToken() async throws -> String {
        if let token, token.isValid { return token.accessToken }
        let token = try await fetchToken()
        self.token = token
        return token.accessToken
    }

    private func fetchToken() async throws -> Token {
        guard let url = URL(string: "https://api.petfinder.com/v2/oauth2/token") else {
            throw PetfinderError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "grant_type=client_credentials",
            "client_id=\(urlEncode(config.clientID))",
            "client_secret=\(urlEncode(config.clientSecret))"
        ].joined(separator: "&")
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        let http = response as? HTTPURLResponse

        if http?.statusCode == 401 {
            throw PetfinderError.unauthorized
        }
        if http?.statusCode == 429 {
            let retryAfter = http?.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
            throw PetfinderError.throttled(retryAfter: retryAfter)
        }
        guard let status = http?.statusCode, (200...299).contains(status) else {
            throw PetfinderError.http(statusCode: http?.statusCode ?? -1)
        }

        do {
            let dto = try decoder.decode(PetfinderTokenResponseDTO.self, from: data)
            let expiration = Date().addingTimeInterval(TimeInterval(dto.expiresIn - 30)) // 30s skew
            return Token(accessToken: dto.accessToken, expiresAt: expiration)
        } catch {
            throw PetfinderError.decoding
        }
    }

    // MARK: - Requests

    private func authedGet<T: Decodable>(path: String, query: [URLQueryItem]) async throws -> T {
        let accessToken = try await ensureValidToken()
        var components = URLComponents(url: config.baseURL, resolvingAgainstBaseURL: false)
        components?.path = path
        components?.queryItems = query.isEmpty ? nil : query

        guard let url = components?.url else { throw PetfinderError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await session.data(for: request)
            let http = response as? HTTPURLResponse

            if http?.statusCode == 401 {
                // Token likely expired/invalid; clear and retry once.
                token = nil
                let accessToken = try await ensureValidToken()
                var retry = request
                retry.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                let (data2, response2) = try await session.data(for: retry)
                return try decodeOrThrow(data2, response2)
            }

            return try decodeOrThrow(data, response)
        } catch let error as PetfinderError {
            throw error
        } catch {
            throw PetfinderError.unknown(message: error.localizedDescription)
        }
    }

    private func decodeOrThrow<T: Decodable>(_ data: Data, _ response: URLResponse) throws -> T {
        let http = response as? HTTPURLResponse
        if http?.statusCode == 429 {
            let retryAfter = http?.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
            throw PetfinderError.throttled(retryAfter: retryAfter)
        }
        guard let status = http?.statusCode, (200...299).contains(status) else {
            // Try to parse Petfinder error body.
            if let status = http?.statusCode,
               let apiError = try? decoder.decode(PetfinderAPIErrorDTO.self, from: data) {
                if status == 401 { throw PetfinderError.unauthorized }
                throw PetfinderError.api(status: apiError.status, title: apiError.title, detail: apiError.detail)
            }
            throw PetfinderError.http(statusCode: http?.statusCode ?? -1)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw PetfinderError.decoding
        }
    }

    private func urlEncode(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? s
    }

    private struct Token: Sendable {
        let accessToken: String
        let expiresAt: Date

        var isValid: Bool { Date() < expiresAt }
    }
}

struct PetfinderAnimalsRequest: Sendable, Hashable {
    var type: String? = "Dog" // Petfinder uses Title Case types
    var location: String = "10001"
    var distance: Int = 50
    var page: Int = 1
    var limit: Int = 50

    func asQueryItems() -> [URLQueryItem] {
        var items: [URLQueryItem] = [
            URLQueryItem(name: "location", value: location),
            URLQueryItem(name: "distance", value: String(distance)),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        if let type, !type.isEmpty {
            items.append(URLQueryItem(name: "type", value: type))
        }
        return items
    }
}












