//
//  NewsArticle.swift
//  PetMatch
//
//  Model for pet news articles
//

import Foundation

struct NewsArticle: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let url: String
    let publishedAt: String
    let source: String
    let imageUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case url
        case publishedAt
        case source
        case imageUrl
    }
    
    init(id: String? = nil, title: String, description: String, url: String, publishedAt: String, source: String, imageUrl: String?) {
        self.id = id ?? url // Use URL as ID if not provided
        self.title = title
        self.description = description
        self.url = url
        self.publishedAt = publishedAt
        self.source = source
        self.imageUrl = imageUrl
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        url = try container.decode(String.self, forKey: .url)
        publishedAt = try container.decode(String.self, forKey: .publishedAt)
        source = try container.decode(String.self, forKey: .source)
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        
        // Use URL as ID if id is not provided
        id = (try? container.decode(String.self, forKey: .id)) ?? url
    }
    
    var articleURL: URL? {
        URL(string: url)
    }
    
    var thumbnailURL: URL? {
        guard let imageUrl = imageUrl else { return nil }
        return URL(string: imageUrl)
    }
    
    var formattedDate: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: publishedAt) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .none
            return displayFormatter.string(from: date)
        }
        
        // Fallback: try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: publishedAt) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .none
            return displayFormatter.string(from: date)
        }
        
        return publishedAt
    }
}

struct PetNewsResponse: Codable {
    let articles: [NewsArticle]
}

