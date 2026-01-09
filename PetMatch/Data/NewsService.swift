//
//  NewsService.swift
//  PetMatch
//
//  Service for fetching pet news articles
//

import Foundation

actor NewsService {
    private let baseURL: String
    private let session: URLSession
    private let decoder: JSONDecoder
    
    init(baseURL: String? = nil, session: URLSession = .shared) {
        // Try to get base URL from parameter, environment variable, or Info.plist
        if let url = baseURL {
            self.baseURL = url
        } else if let url = Self.getBaseURLFromConfiguration() {
            self.baseURL = url
        } else {
            // Default: localhost for development
            // TODO: Replace with your Render URL after deployment
            // Example: "https://petmatch-api.onrender.com"
            self.baseURL = "http://localhost:3000"
        }
        self.session = session
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = decoder
    }
    
    /// Get base URL from environment variables or Info.plist
    private static func getBaseURLFromConfiguration() -> String? {
        let env = ProcessInfo.processInfo.environment
        let info = Bundle.main.infoDictionary ?? [:]
        
        // Try environment variable first
        if let url = env["PETMATCH_API_URL"] as String? {
            return url
        }
        
        // Try Info.plist
        if let url = info["PETMATCH_API_URL"] as? String {
            return url
        }
        
        return nil
    }
    
    func fetchPetNews() async throws -> [NewsArticle] {
        guard let url = URL(string: "\(baseURL)/api/pet-news") else {
            throw NewsError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NewsError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw NewsError.httpError(statusCode: httpResponse.statusCode)
            }
            
            let newsResponse = try decoder.decode(PetNewsResponse.self, from: data)
            return newsResponse.articles
        } catch let error as DecodingError {
            throw NewsError.decodingError(error.localizedDescription)
        } catch let error as NewsError {
            throw error
        } catch {
            throw NewsError.networkError(error.localizedDescription)
        }
    }
}

enum NewsError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError(String)
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        case .decodingError(let message):
            return "Decoding error: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}

