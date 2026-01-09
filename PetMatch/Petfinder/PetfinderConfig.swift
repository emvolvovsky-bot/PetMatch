import Foundation

struct PetfinderConfig: Sendable {
    let baseURL: URL
    let clientID: String
    let clientSecret: String

    init(
        baseURL: URL = URL(string: "https://api.petfinder.com/v2")!,
        clientID: String,
        clientSecret: String
    ) {
        self.baseURL = baseURL
        self.clientID = clientID
        self.clientSecret = clientSecret
    }

    static func fromRuntimeConfiguration() throws -> PetfinderConfig {
        let env = ProcessInfo.processInfo.environment
        let info = Bundle.main.infoDictionary ?? [:]

        let clientID = (env["PETFINDER_CLIENT_ID"] as String?) ??
            (info["PETFINDER_CLIENT_ID"] as? String) ??
            ""
        let clientSecret = (env["PETFINDER_CLIENT_SECRET"] as String?) ??
            (info["PETFINDER_CLIENT_SECRET"] as? String) ??
            ""

        guard !clientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PetfinderError.missingClientID
        }
        guard !clientSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PetfinderError.missingClientSecret
        }

        return PetfinderConfig(clientID: clientID, clientSecret: clientSecret)
    }
}












