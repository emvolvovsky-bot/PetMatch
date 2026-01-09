import Foundation

struct PetfinderAPIErrorDTO: Decodable, Sendable {
    let type: String?
    let status: Int?
    let title: String?
    let detail: String?
}

enum PetfinderError: Error, LocalizedError, Sendable, Equatable {
    case missingClientID
    case missingClientSecret
    case invalidURL
    case http(statusCode: Int)
    case api(status: Int?, title: String?, detail: String?)
    case unauthorized
    case throttled(retryAfter: TimeInterval?)
    case decoding
    case unknown(message: String)

    var errorDescription: String? {
        switch self {
        case .missingClientID:
            return "Missing Petfinder client id. Configure PETFINDER_CLIENT_ID in your scheme environment variables."
        case .missingClientSecret:
            return "Missing Petfinder client secret. Configure PETFINDER_CLIENT_SECRET in your scheme environment variables."
        case .invalidURL:
            return "Couldn’t build the Petfinder request."
        case .http(let statusCode):
            return "Network error (\(statusCode)). Please try again."
        case .api(_, let title, let detail):
            return [title, detail].compactMap { $0 }.joined(separator: ": ")
        case .unauthorized:
            return "Petfinder authorization failed. Double-check your credentials."
        case .throttled:
            return "Petfinder is temporarily unavailable. Please try again shortly."
        case .decoding:
            return "Couldn’t read the Petfinder response."
        case .unknown(let message):
            return message
        }
    }
}












