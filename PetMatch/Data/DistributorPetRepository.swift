import Foundation

/// Repository that fetches pets from Petfinder-Database-Distributor CSV API
/// 
/// SECURITY NOTE: In production, this API key should be stored server-side only.
/// This implementation reads from key.txt for development purposes.
/// Consider moving this to a server-side API endpoint in production.
final class DistributorPetRepository: PetRepository {
    private let baseURL = "https://petfinder-database-distributor.onrender.com"
    private let apiKey: String
    private var cachedPets: [Pet] = []
    private var currentIndex: Int = 0
    private var hasLoadedInitialData = false
    
    init(apiKey: String? = nil) {
        // Try to get API key from parameter, then from key.txt file
        if let key = apiKey {
            self.apiKey = key
        } else if let keyFromFile = Self.loadKeyFromFile() {
            self.apiKey = keyFromFile
        } else {
            // Fallback - should not happen in production
            self.apiKey = "3h4hdfbhdfesnfsd2439DSFNUIFGSDBJHF"
        }
    }
    
    /// Load API key from key.txt file
    /// Tries multiple locations: bundle resource, project root, and Documents directory
    private static func loadKeyFromFile() -> String? {
        // Try 1: Bundle resource (for when key.txt is added to Xcode project)
        if let keyPath = Bundle.main.path(forResource: "key", ofType: "txt"),
           let key = try? String(contentsOfFile: keyPath).trimmingCharacters(in: .whitespacesAndNewlines),
           !key.isEmpty {
            return key
        }
        
        // Try 2: Project root (for development)
        let projectRoot = FileManager.default.currentDirectoryPath
        let projectKeyPath = (projectRoot as NSString).appendingPathComponent("key.txt")
        if let key = try? String(contentsOfFile: projectKeyPath).trimmingCharacters(in: .whitespacesAndNewlines),
           !key.isEmpty {
            return key
        }
        
        // Try 3: Documents directory
        if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
           let key = try? String(contentsOfFile: documentsPath.appendingPathComponent("key.txt").path).trimmingCharacters(in: .whitespacesAndNewlines),
           !key.isEmpty {
            return key
        }
        
        return nil
    }
    
    func loadSearchForm(species: String) async throws -> PetSearchForm {
        PetSearchForm()
    }
    
    func loadInitialPets() async throws -> [Pet] {
        currentIndex = 0
        hasLoadedInitialData = false
        
        // Fetch and cache all pets
        if cachedPets.isEmpty {
            cachedPets = try await fetchAllPets()
        }
        
        // Shuffle the cached pets array so we get different pets each time
        cachedPets.shuffle()
        
        hasLoadedInitialData = true
        let batchSize = 20
        let endIndex = min(batchSize, cachedPets.count)
        currentIndex = endIndex
        
        return Array(cachedPets[0..<endIndex])
    }
    
    func loadMorePetsIfAvailable() async throws -> [Pet] {
        // If we haven't loaded initial data yet, do that first
        if !hasLoadedInitialData {
            return try await loadInitialPets()
        }
        
        // Return next batch
        let batchSize = 20
        guard currentIndex < cachedPets.count else {
            return [] // No more pets
        }
        
        let endIndex = min(currentIndex + batchSize, cachedPets.count)
        let batch = Array(cachedPets[currentIndex..<endIndex])
        currentIndex = endIndex
        
        return batch
    }
    
    func loadPetDetails(petID: String) async throws -> Pet {
        // If we haven't loaded data yet, fetch it
        if cachedPets.isEmpty {
            cachedPets = try await fetchAllPets()
        }
        
        // Find the pet by ID - try exact match first
        if let pet = cachedPets.first(where: { $0.id == petID }) {
            return pet
        }
        
        // If exact match fails, the pet might have been passed in with a different ID format
        // Since we already have all pet data from CSV, we can't really "reload" more details
        // So we'll throw an error and let the view model keep the original pet
        // This prevents showing the wrong pet (like always showing Brandi)
        throw NSError(domain: "DistributorPetRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Pet not found with ID: \(petID). Using original pet data."])
    }
    
    // MARK: - CSV Fetching and Parsing
    
    private func fetchAllPets() async throws -> [Pet] {
        // Try to load from local CSV file first
        if let csvString = try? loadLocalCSV() {
            return try parseCSV(csvString)
        }
        
        // Fallback to API if local file not found
        guard let url = URL(string: "\(baseURL)/pets.csv") else {
            throw NSError(domain: "DistributorPetRepository", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "DistributorPetRepository", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "DistributorPetRepository", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API error: \(errorMessage)"])
        }
        
        guard let csvString = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "DistributorPetRepository", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to decode CSV"])
        }
        
        return try parseCSV(csvString)
    }
    
    /// Load CSV from local file system
    private func loadLocalCSV() throws -> String {
        // Try 1: Bundle resource (for when pets.csv is added to Xcode project)
        if let bundlePath = Bundle.main.path(forResource: "pets", ofType: "csv"),
           let csvString = try? String(contentsOfFile: bundlePath, encoding: .utf8),
           !csvString.isEmpty {
            return csvString
        }
        
        // Try 2: Documents directory (most reliable for iOS apps)
        if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let documentsCSVPath = documentsPath.appendingPathComponent("pets.csv")
            if let csvString = try? String(contentsOfFile: documentsCSVPath.path, encoding: .utf8),
               !csvString.isEmpty {
                return csvString
            }
        }
        
        // Try 3: Absolute path (for simulator/development)
        #if targetEnvironment(simulator)
        let absolutePaths = [
            "/Users/evolvovsky26/Documents/PetMatch/pets.csv",
            NSHomeDirectory() + "/Documents/PetMatch/pets.csv",
            NSHomeDirectory() + "/Desktop/PetMatch/pets.csv"
        ]
        
        for path in absolutePaths {
            if let csvString = try? String(contentsOfFile: path, encoding: .utf8),
               !csvString.isEmpty {
                return csvString
            }
        }
        #endif
        
        // Try 4: Current working directory (for command line tools)
        let projectRoot = FileManager.default.currentDirectoryPath
        let projectCSVPath = (projectRoot as NSString).appendingPathComponent("pets.csv")
        if let csvString = try? String(contentsOfFile: projectCSVPath, encoding: .utf8),
           !csvString.isEmpty {
            return csvString
        }
        
        throw NSError(domain: "DistributorPetRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Local pets.csv file not found. Please add pets.csv to the app bundle or Documents directory."])
    }
    
    private func parseCSV(_ csvContent: String) throws -> [Pet] {
        let lines = csvContent.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        
        guard lines.count > 1 else {
            return []
        }
        
        // Parse header
        let headers = parseCSVLine(lines[0])
        guard let linkIndex = headers.firstIndex(of: "link"),
              let petTypeIndex = headers.firstIndex(of: "pet_type"),
              let nameIndex = headers.firstIndex(of: "name"),
              let locationIndex = headers.firstIndex(of: "location"),
              let ageIndex = headers.firstIndex(of: "age"),
              let genderIndex = headers.firstIndex(of: "gender"),
              let sizeIndex = headers.firstIndex(of: "size"),
              let breedIndex = headers.firstIndex(of: "breed"),
              let specialNeedsIndex = headers.firstIndex(of: "special_needs"),
              let kidsCompatibleIndex = headers.firstIndex(of: "kids_compatible"),
              let aboutMeIndex = headers.firstIndex(of: "about_me"),
              let imageIndex = headers.firstIndex(of: "image") else {
            throw NSError(domain: "DistributorPetRepository", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid CSV format: missing required columns"])
        }
        
        // Optional fields
        let spayedNeuteredIndex = headers.firstIndex(of: "spayed_neutered")
        let vaccinatedIndex = headers.firstIndex(of: "vaccinated")
        let dogsCompatibleIndex = headers.firstIndex(of: "dogs_compatible")
        let catsCompatibleIndex = headers.firstIndex(of: "cats_compatible")
        
        var pets: [Pet] = []
        
        // Parse data rows
        for i in 1..<lines.count {
            let values = parseCSVLine(lines[i])
            
            guard values.count == headers.count else {
                continue // Skip malformed rows
            }
            
            let link = values[linkIndex]
            let petType = values[petTypeIndex].lowercased()
            let name = values[nameIndex].trimmingCharacters(in: .whitespaces)
            
            // Skip pets with empty names - don't create placeholder pets
            guard !name.isEmpty else {
                continue
            }
            
            let location = values[locationIndex]
            let age = values[ageIndex].lowercased()
            let gender = values[genderIndex]
            let size = values[sizeIndex].lowercased()
            
            // Parse breed - handle combined breeds like "Labrador Retriever&American Staffordshire TerrierMix"
            let breedString = values[breedIndex].isEmpty ? "Mixed" : values[breedIndex]
            let breedParts = breedString.components(separatedBy: "&").map { $0.trimmingCharacters(in: .whitespaces) }
            let primaryBreed = breedParts.first?.replacingOccurrences(of: "Mix", with: "").trimmingCharacters(in: .whitespaces) ?? "Mixed"
            let secondaryBreed = breedParts.count > 1 ? breedParts[1].replacingOccurrences(of: "Mix", with: "").trimmingCharacters(in: .whitespaces) : nil
            
            let specialNeeds = values[specialNeedsIndex].lowercased() == "true"
            
            // Parse kids_compatible - blank fields = Unknown (nil), only explicit "True"/"False" map to boolean
            let kidsCompatible: Bool? = {
                let value = values[kidsCompatibleIndex].lowercased().trimmingCharacters(in: .whitespaces)
                if value.isEmpty {
                    return nil // Blank field = Unknown
                }
                if value == "true" {
                    return true
                }
                if value == "false" {
                    return false
                }
                return nil // Invalid value = Unknown
            }()
            
            let aboutMe = values[aboutMeIndex].replacingOccurrences(of: "\\n", with: "\n")
            let imageURLString = values[imageIndex]
            
            // Parse optional boolean fields
            // Rule: Empty/blank fields = Unknown (nil), only explicit "True"/"False" map to boolean values
            let spayedNeutered: Bool? = {
                guard let index = spayedNeuteredIndex, index < values.count else { return nil }
                let value = values[index].lowercased().trimmingCharacters(in: .whitespaces)
                if value.isEmpty {
                    return nil // Blank field = Unknown
                }
                if value == "true" {
                    return true
                }
                if value == "false" {
                    return false
                }
                return nil // Invalid value = Unknown
            }()
            
            let vaccinated: Bool? = {
                guard let index = vaccinatedIndex, index < values.count else { return nil }
                let value = values[index].lowercased().trimmingCharacters(in: .whitespaces)
                if value.isEmpty {
                    return nil // Blank field = Unknown
                }
                if value == "true" {
                    return true
                }
                if value == "false" {
                    return false
                }
                return nil // Invalid value = Unknown
            }()
            
            let dogsCompatible: Bool? = {
                guard let index = dogsCompatibleIndex, index < values.count else { return nil }
                let value = values[index].lowercased().trimmingCharacters(in: .whitespaces)
                if value.isEmpty {
                    return nil // Blank field = Unknown
                }
                if value == "true" {
                    return true
                }
                if value == "false" {
                    return false
                }
                return nil // Invalid value = Unknown
            }()
            
            let catsCompatible: Bool? = {
                guard let index = catsCompatibleIndex, index < values.count else { return nil }
                let value = values[index].lowercased().trimmingCharacters(in: .whitespaces)
                if value.isEmpty {
                    return nil // Blank field = Unknown
                }
                if value == "true" {
                    return true
                }
                if value == "false" {
                    return false
                }
                return nil // Invalid value = Unknown
            }()
            
            // Parse location (format: "City, State" or just "City" or "State")
            let locationParts = location.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            let city = locationParts.count > 0 ? locationParts[0] : nil
            let state = locationParts.count > 1 ? locationParts[1] : nil
            
            // Create image URLs
            let imageURL = URL(string: imageURLString)
            let allImageURLs = imageURL != nil ? [imageURL!] : []
            
            // Normalize gender
            let sexRaw: String? = {
                let g = gender.lowercased()
                if g.contains("male") && !g.contains("female") { return "m" }
                if g.contains("female") { return "f" }
                return nil
            }()
            
            // Normalize size
            let normalizedSize: String? = {
                let s = size.lowercased()
                if s.contains("small") || s == "s" { return "s" }
                if s.contains("medium") || s == "m" { return "m" }
                if s.contains("large") || s == "l" { return "l" }
                if s.contains("extra") || s == "xl" { return "xl" }
                return size.isEmpty ? nil : size
            }()
            
            // Normalize age
            let normalizedAge: String = {
                let a = age.lowercased()
                // Handle age ranges like "(3-8 years)" or "(8+ years)"
                if a.contains("8+") || a.contains("9+") || a.contains("10+") || a.contains("senior") {
                    return "senior"
                }
                if a.contains("puppy") || a.contains("kitten") || a.contains("baby") || a.contains("0-1") || a.contains("1-2") {
                    return "puppy"
                }
                if a.contains("young") || a.contains("2-3") || a.contains("3-4") {
                    return "young"
                }
                if a.contains("adult") || a.contains("4-5") || a.contains("5-6") || a.contains("6-7") || a.contains("7-8") {
                    return "adult"
                }
                return age.isEmpty ? "adult" : age
            }()
            
            // Use link as ID (extract ID from URL if possible, or use a more unique hash)
            // Combine link + name + location to create a unique ID if extraction fails
            let petID: String
            if let extractedID = extractIDFromLink(link), !extractedID.isEmpty {
                petID = extractedID
            } else {
                // Create a more unique ID by combining multiple fields
                let uniqueString = "\(link)|\(name)|\(location)"
                petID = String(uniqueString.hash)
            }
            
            // Determine energy level (heuristic based on breed and age)
            let energy: EnergyLevel = {
                if normalizedAge == "puppy" { return .high }
                if normalizedAge == "senior" { return .low }
                // Could add breed-based logic here
                return .medium
            }()
            
            // Determine apartment friendly (heuristic based on size)
            let apartmentFriendly = normalizedSize == "s" || normalizedSize == "m"
            
            let pet = Pet(
                id: petID,
                name: name,
                species: petType,
                primaryBreed: primaryBreed,
                secondaryBreed: secondaryBreed,
                age: normalizedAge,
                sexRaw: sexRaw,
                size: normalizedSize,
                city: city,
                state: state,
                thumbnailImageURL: imageURL,
                largeImageURL: imageURL,
                allImageURLs: allImageURLs,
                detailsURL: URL(string: link),
                specialNeeds: specialNeeds,
                purebred: false, // CSV doesn't provide this
                bondedPair: false, // CSV doesn't provide this
                spayedNeutered: spayedNeutered,
                vaccinated: vaccinated,
                dogsCompatible: dogsCompatible,
                catsCompatible: catsCompatible,
                goodWithKids: kidsCompatible, // Preserve nil for Unknown state
                bio: aboutMe.isEmpty ? "Tap to see more photos and details." : aboutMe,
                energy: energy,
                apartmentFriendly: apartmentFriendly
            )
            
            pets.append(pet)
        }
        
        return pets
    }
    
    private func parseCSVLine(_ line: String) -> [String] {
        var values: [String] = []
        var current = ""
        var inQuotes = false
        var chars = Array(line)
        
        var i = 0
        while i < chars.count {
            let char = chars[i]
            
            if char == "\"" {
                // Handle escaped quotes ("")
                if i + 1 < chars.count && chars[i + 1] == "\"" {
                    current.append("\"")
                    i += 2
                    continue
                }
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                values.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(char)
            }
            i += 1
        }
        
        // Add the last value
        values.append(current.trimmingCharacters(in: .whitespaces))
        
        return values
    }
    
    private func extractIDFromLink(_ link: String) -> String? {
        // Try to extract ID from Petfinder URL
        // Example: https://www.petfinder.com/dog/name-12345678/
        if let url = URL(string: link),
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let pathComponents = components.path.components(separatedBy: "/").last,
           let id = pathComponents.components(separatedBy: "-").last {
            return id
        }
        return nil
    }
}

