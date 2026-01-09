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
    
    init(baseURL: String = "http://localhost:3000", session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = decoder
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

