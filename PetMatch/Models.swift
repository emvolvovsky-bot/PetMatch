//
//  Models.swift
//  PetMatch
//

import Foundation

// MARK: - String Extensions

extension String {
    /// Strips all HTML tags from the string
    func strippingHTML() -> String {
        var result = self
        
        // Replace common HTML entities first
        result = result.replacingOccurrences(of: "&nbsp;", with: " ")
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        result = result.replacingOccurrences(of: "&quot;", with: "\"")
        result = result.replacingOccurrences(of: "&#39;", with: "'")
        result = result.replacingOccurrences(of: "&apos;", with: "'")
        
        // Remove all HTML tags using regex
        // This pattern matches <...> including self-closing tags like <br/>
        if let regex = try? NSRegularExpression(pattern: "<[^>]+>", options: []) {
            let range = NSRange(location: 0, length: result.utf16.count)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "")
        }
        
        // Clean up multiple spaces and newlines
        result = result.replacingOccurrences(of: "  ", with: " ")
        result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Removes "Show more" and similar UI text from bio content
    func removingShowMoreText() -> String {
        var result = self
        
        // Common patterns to remove (case-insensitive)
        let patterns = [
            "Show more",
            "show more",
            "Show More",
            "SHOW MORE",
            "Tap to see more",
            "tap to see more",
            "Tap to see more photos and details",
            "tap to see more photos and details",
            "Click to see more",
            "click to see more",
            "Read more",
            "read more",
            "See more",
            "see more",
            "Learn more",
            "learn more",
            "View more",
            "view more",
            "\\[.*more.*\\]",  // [Show more], [Read more], etc.
            "\\.\\.\\.more",   // ...more
            "more\\.\\.\\."    // more...
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(location: 0, length: result.utf16.count)
                result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "")
            }
        }
        
        // Clean up any extra whitespace left behind
        result = result.replacingOccurrences(of: "  ", with: " ")
        result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum EnergyLevel: String, Codable, CaseIterable {
    case low, medium, high

    var chip: TraitChip {
        switch self {
        case .high:
            return TraitChip(label: "High energy", background: "#FFE4E0", foreground: "#C2410C")
        case .medium:
            return TraitChip(label: "Moderate energy", background: "#FEF9C3", foreground: "#92400E")
        case .low:
            return TraitChip(label: "Low energy", background: "#DCFCE7", foreground: "#166534")
        }
    }
}

struct TraitChip: Identifiable, Hashable, Codable {
    var id = UUID()
    let label: String
    let background: String
    let foreground: String
}

/// Normalized domain model used by the UI.
///
/// Most fields map directly from Adopt-a-Pet Basic API responses.
/// The UI-friendly strings (like `breedDisplay`, `ageDisplay`, `locationDisplay`) are computed so we can keep the existing UI intact.
struct Pet: Identifiable, Hashable, Codable {
    // MARK: - Normalized fields (from API)
    let id: String // pet_id
    let name: String // pet_name
    let species: String
    let primaryBreed: String
    let secondaryBreed: String?
    let age: String // e.g. puppy/kitten/young/adult/senior
    let sexRaw: String? // "m" / "f"
    let size: String?
    let city: String?
    let state: String?
    let thumbnailImageURL: URL?
    let largeImageURL: URL?
    let allImageURLs: [URL]
    let detailsURL: URL? // pet_details_url/details_url
    let specialNeeds: Bool
    let purebred: Bool
    let bondedPair: Bool
    
    // MARK: - Health & Status fields (from CSV)
    let spayedNeutered: Bool?
    let vaccinated: Bool?
    
    // MARK: - Compatibility fields (from CSV)
    let dogsCompatible: Bool?
    let catsCompatible: Bool?
    let goodWithKids: Bool?

    // MARK: - UI helper fields (not provided by API; safe defaults)
    let bio: String
    let energy: EnergyLevel
    let apartmentFriendly: Bool

    var chips: [TraitChip] {
        var items: [TraitChip] = [energy.chip]
        if goodWithKids == true {
            items.append(TraitChip(label: "Kid friendly", background: "#DCFCE7", foreground: "#166534"))
        }
        if apartmentFriendly {
            items.append(TraitChip(label: "Apartment friendly", background: "#E0F2FE", foreground: "#075985"))
        }
        if specialNeeds {
            items.append(TraitChip(label: "Special needs", background: "#FEE2E2", foreground: "#991B1B"))
        }
        
        // Extract additional traits from bio text
        items.append(contentsOf: extractBioTraits())
        
        return items
    }
    
    /// Chips that fit on one line for card view (prioritizes most important traits)
    var cardChips: [TraitChip] {
        var items: [TraitChip] = [energy.chip]
        var seenLabels: Set<String> = [energy.chip.label]
        
        // Always include energy level
        // Then add key traits that are short and important
        if goodWithKids == true {
            items.append(TraitChip(label: "Kid friendly", background: "#DCFCE7", foreground: "#166534"))
            seenLabels.insert("Kid friendly")
        }
        if specialNeeds {
            items.append(TraitChip(label: "Special needs", background: "#FEE2E2", foreground: "#991B1B"))
            seenLabels.insert("Special needs")
        }
        
        // Add short bio traits (prioritize medical/important ones)
        let bioTraits = extractBioTraits()
        let shortImportantTraits = bioTraits.filter { trait in
            let label = trait.label.lowercased()
            // Prioritize: neutered/spayed, vaccinated, house trained, microchipped
            return (label.contains("neutered") || label.contains("spayed") || 
                   label.contains("vaccinated") || label.contains("house trained") ||
                   label.contains("microchipped")) && !seenLabels.contains(trait.label)
        }
        
        // Add up to 2 more short important traits
        for trait in shortImportantTraits.prefix(2) {
            items.append(trait)
            seenLabels.insert(trait.label)
        }
        
        // Limit to 4 chips max for card view
        return Array(items.prefix(4))
    }
    
    /// Extracts trait chips from the pet's bio text
    private func extractBioTraits() -> [TraitChip] {
        let bioLower = bio.lowercased()
        var traits: [TraitChip] = []
        
        // Spay/Neuter status - improved detection
        if bioLower.contains("neutered") || bioLower.contains("altered") || bioLower.contains("neutered,") {
            traits.append(TraitChip(label: "Neutered", background: "#E0E7FF", foreground: "#3730A3"))
        } else if bioLower.contains("spayed") || bioLower.contains("spayed,") {
            traits.append(TraitChip(label: "Spayed", background: "#E0E7FF", foreground: "#3730A3"))
        }
        
        // Weight/Pounds extraction
        let weightPattern = #"(\d+)\s*(?:lbs?|pounds?|lb\.)"#
        if let regex = try? NSRegularExpression(pattern: weightPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: bio, options: [], range: NSRange(bio.startIndex..., in: bio)),
           let weightRange = Range(match.range(at: 1), in: bio),
           let weight = Int(bio[weightRange]) {
            traits.append(TraitChip(label: "\(weight) lbs", background: "#FEF3C7", foreground: "#92400E"))
        } else if bioLower.contains("weighs") {
            // Try to extract weight from "weighs X" pattern
            let weighsPattern = #"weighs\s+(\d+)"#
            if let regex = try? NSRegularExpression(pattern: weighsPattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: bio, options: [], range: NSRange(bio.startIndex..., in: bio)),
               let weightRange = Range(match.range(at: 1), in: bio),
               let weight = Int(bio[weightRange]) {
                traits.append(TraitChip(label: "\(weight) lbs", background: "#FEF3C7", foreground: "#92400E"))
            }
        }
        
        // House training
        if bioLower.contains("house trained") || bioLower.contains("house-trained") || 
           bioLower.contains("potty trained") || bioLower.contains("potty-trained") ||
           bioLower.contains("housebroken") || bioLower.contains("house broken") {
            traits.append(TraitChip(label: "House trained", background: "#DCFCE7", foreground: "#166534"))
        }
        
        // Microchip
        if bioLower.contains("microchip") || bioLower.contains("micro-chipped") || bioLower.contains("chipped") ||
           bioLower.contains("has microchip") {
            traits.append(TraitChip(label: "Microchipped", background: "#F3E8FF", foreground: "#6B21A8"))
        }
        
        // Vaccination - improved detection
        if bioLower.contains("vaccinated") || bioLower.contains("up to date") || bioLower.contains("up-to-date") ||
           bioLower.contains("shots") || bioLower.contains("vaxxed") || bioLower.contains("current on shots") ||
           bioLower.contains("all shots") || bioLower.contains("vaccinations") {
            traits.append(TraitChip(label: "Vaccinated", background: "#D1FAE5", foreground: "#065F46"))
        }
        
        // Good with other animals - expanded detection
        if bioLower.contains("good with dogs") || bioLower.contains("dog friendly") || bioLower.contains("loves dogs") ||
           bioLower.contains("gets along with dogs") || bioLower.contains("dog social") ||
           bioLower.contains("good around dogs") {
            traits.append(TraitChip(label: "Dog friendly", background: "#FEF3C7", foreground: "#92400E"))
        }
        if bioLower.contains("good with cats") || bioLower.contains("cat friendly") || bioLower.contains("loves cats") ||
           bioLower.contains("gets along with cats") || bioLower.contains("cat social") ||
           bioLower.contains("good around cats") {
            traits.append(TraitChip(label: "Cat friendly", background: "#FEF3C7", foreground: "#92400E"))
        }
        if bioLower.contains("good with other animals") || bioLower.contains("animal friendly") ||
           bioLower.contains("gets along with other pets") {
            traits.append(TraitChip(label: "Pet friendly", background: "#FEF3C7", foreground: "#92400E"))
        }
        
        // Training
        if bioLower.contains("crate trained") || bioLower.contains("crate-trained") || bioLower.contains("crate trained") {
            traits.append(TraitChip(label: "Crate trained", background: "#E0F2FE", foreground: "#075985"))
        }
        if bioLower.contains("leash trained") || bioLower.contains("leash-trained") || bioLower.contains("walks well") ||
           bioLower.contains("leash trained") {
            traits.append(TraitChip(label: "Leash trained", background: "#E0F2FE", foreground: "#075985"))
        }
        
        // Behavioral traits
        if bioLower.contains("calm") || bioLower.contains("gentle") || bioLower.contains("mellow") {
            traits.append(TraitChip(label: "Calm", background: "#F0FDF4", foreground: "#166534"))
        }
        if bioLower.contains("playful") || bioLower.contains("loves to play") {
            traits.append(TraitChip(label: "Playful", background: "#FEF3C7", foreground: "#92400E"))
        }
        if bioLower.contains("affectionate") || bioLower.contains("cuddly") || bioLower.contains("loves cuddles") {
            traits.append(TraitChip(label: "Affectionate", background: "#FEE2E2", foreground: "#991B1B"))
        }
        
        // Health/Medical
        if bioLower.contains("healthy") || bioLower.contains("in good health") {
            traits.append(TraitChip(label: "Healthy", background: "#D1FAE5", foreground: "#065F46"))
        }
        
        // Return unique traits (avoid duplicates by label)
        var uniqueTraits: [TraitChip] = []
        var seenLabels: Set<String> = []
        for trait in traits {
            if !seenLabels.contains(trait.label) {
                seenLabels.insert(trait.label)
                uniqueTraits.append(trait)
            }
        }
        return uniqueTraits
    }

    var breedDisplay: String {
        if let secondaryBreed, !secondaryBreed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "\(primaryBreed) • \(secondaryBreed)"
        }
        return primaryBreed
    }

    var sexDisplay: String {
        switch sexRaw?.lowercased() {
        case "m": return "Male"
        case "f": return "Female"
        default: return "Unknown"
        }
    }

    var ageDisplay: String {
        // Keep it simple and deterministic; API provides a category.
        age.replacingOccurrences(of: "_", with: " ").capitalized
    }

    var locationDisplay: String {
        let city = city?.trimmingCharacters(in: .whitespacesAndNewlines)
        let state = state?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let city, !city.isEmpty, let state, !state.isEmpty { return "\(city), \(state)" }
        if let city, !city.isEmpty { return city }
        if let state, !state.isEmpty { return state }
        return "Nearby"
    }

    /// Backwards-compatible name used by existing UI components.
    var thumbnail: URL? { thumbnailImageURL ?? allImageURLs.first ?? largeImageURL }

    /// Backwards-compatible array used by the existing carousel.
    var photos: [URL] {
        let preferred = allImageURLs.isEmpty ? [largeImageURL, thumbnailImageURL].compactMap { $0 } : allImageURLs
        // De-dupe while preserving order.
        var seen = Set<URL>()
        return preferred.filter { seen.insert($0).inserted }
    }

    /// Backwards-compatible alias for older UI code.
    var adoptionURL: URL? { detailsURL }

    var isCat: Bool {
        let lower = (species.isEmpty ? breedDisplay : species).lowercased()
        return lower.contains("cat")
            || lower.contains("tabby")
            || lower.contains("domestic")
            || lower.contains("short hair")
            || lower.contains("long hair")
    }

    var animalEmoji: String {
        isCat ? "🐱" : "🐶"
    }
    
    /// Returns true if at least one health/status field has a value (not nil)
    var hasHealthStatus: Bool {
        spayedNeutered != nil || vaccinated != nil || specialNeeds
    }
    
    /// Returns true if at least one compatibility field has a value (not nil)
    var hasCompatibility: Bool {
        goodWithKids != nil || dogsCompatible != nil || catsCompatible != nil
    }
}

enum SwipeDirection {
    case like, nope
}

/// Model for pet filtering criteria
struct PetFilters: Codable, Hashable {
    var species: Set<String> = ["dog", "cat"] // Default: show both
    var breeds: Set<String> = [] // Empty means all breeds
    var ages: Set<String> = [] // Empty means all ages
    var sizes: Set<String> = [] // Empty means all sizes
    var genders: Set<String> = [] // Empty means all genders
    var vaccinated: Bool? = nil // nil = any, true = vaccinated only, false = not vaccinated
    var colors: Set<String> = [] // Empty means all colors
    var goodWithKids: Bool? = nil // nil = any, true = good with kids, false = not good with kids
    var dogsCompatible: Bool? = nil // nil = any, true = good with dogs, false = not good with dogs
    var catsCompatible: Bool? = nil // nil = any, true = good with cats, false = not good with cats
    
    // Location filter
    var locationLatitude: Double? = nil
    var locationLongitude: Double? = nil
    var locationRadiusMiles: Double? = nil // Search radius in miles
    
    var isEmpty: Bool {
        species == ["dog", "cat"] &&
        breeds.isEmpty &&
        ages.isEmpty &&
        sizes.isEmpty &&
        genders.isEmpty &&
        vaccinated == nil &&
        colors.isEmpty &&
        goodWithKids == nil &&
        dogsCompatible == nil &&
        catsCompatible == nil &&
        locationLatitude == nil &&
        locationLongitude == nil &&
        locationRadiusMiles == nil
    }
    
    var hasLocationFilter: Bool {
        locationLatitude != nil && locationLongitude != nil && locationRadiusMiles != nil
    }
    
    mutating func reset() {
        self = PetFilters()
    }
}

enum SamplePets {
    static let all: [Pet] = [
        Pet(
            id: "sample-1",
            name: "Luna",
            species: "dog",
            primaryBreed: "Border Collie Mix",
            secondaryBreed: nil,
            age: "adult",
            sexRaw: "f",
            size: "m",
            city: "Austin",
            state: "TX",
            thumbnailImageURL: URL(string: "https://images.unsplash.com/photo-1548199973-03cce0bbc87b?auto=format&fit=crop&w=1400&q=80"),
            largeImageURL: URL(string: "https://images.unsplash.com/photo-1548199973-03cce0bbc87b?auto=format&fit=crop&w=1400&q=80"),
            allImageURLs: [
                URL(string: "https://images.unsplash.com/photo-1548199973-03cce0bbc87b?auto=format&fit=crop&w=1400&q=80")!,
                URL(string: "https://images.unsplash.com/photo-1507146426996-ef05306b995a?auto=format&fit=crop&w=1400&q=80")!
            ],
            detailsURL: URL(string: "https://www.petfinder.com"),
            specialNeeds: false,
            purebred: false,
            bondedPair: false,
            spayedNeutered: nil,
            vaccinated: nil,
            dogsCompatible: nil,
            catsCompatible: nil,
            goodWithKids: true,
            bio: "Brilliant, affectionate, and obsessed with fetch. Luna loves trail runs and will happily crash for a cuddle session afterward.",
            energy: .high,
            apartmentFriendly: false
        ),
        Pet(
            id: "sample-2",
            name: "Milo",
            species: "cat",
            primaryBreed: "Ginger Tabby",
            secondaryBreed: nil,
            age: "young",
            sexRaw: "m",
            size: "s",
            city: "Seattle",
            state: "WA",
            thumbnailImageURL: URL(string: "https://images.unsplash.com/photo-1518791841217-8f162f1e1131?auto=format&fit=crop&w=1400&q=80"),
            largeImageURL: URL(string: "https://images.unsplash.com/photo-1518791841217-8f162f1e1131?auto=format&fit=crop&w=1400&q=80"),
            allImageURLs: [
                URL(string: "https://images.unsplash.com/photo-1518791841217-8f162f1e1131?auto=format&fit=crop&w=1400&q=80")!,
                URL(string: "https://images.unsplash.com/photo-1494256997604-768d1f608cac?auto=format&fit=crop&w=1400&q=80")!
            ],
            detailsURL: URL(string: "https://www.petfinder.com"),
            specialNeeds: false,
            purebred: false,
            bondedPair: false,
            spayedNeutered: nil,
            vaccinated: nil,
            dogsCompatible: nil,
            catsCompatible: nil,
            goodWithKids: true,
            bio: "Playful shadow with a loud purr. Milo loves window sunbaths and chasing feather toys before curling up in a lap.",
            energy: .medium,
            apartmentFriendly: true
        ),
        Pet(
            id: "sample-3",
            name: "Bella",
            species: "dog",
            primaryBreed: "Golden Retriever",
            secondaryBreed: nil,
            age: "puppy",
            sexRaw: "f",
            size: "l",
            city: "Portland",
            state: "OR",
            thumbnailImageURL: URL(string: "https://images.unsplash.com/photo-1552053831-71594a27632d?auto=format&fit=crop&w=1400&q=80"),
            largeImageURL: URL(string: "https://images.unsplash.com/photo-1552053831-71594a27632d?auto=format&fit=crop&w=1400&q=80"),
            allImageURLs: [
                URL(string: "https://images.unsplash.com/photo-1552053831-71594a27632d?auto=format&fit=crop&w=1400&q=80")!,
                URL(string: "https://images.unsplash.com/photo-1587300003388-59208cc962cb?auto=format&fit=crop&w=1400&q=80")!
            ],
            detailsURL: URL(string: "https://www.petfinder.com"),
            specialNeeds: false,
            purebred: false,
            bondedPair: false,
            spayedNeutered: nil,
            vaccinated: nil,
            dogsCompatible: nil,
            catsCompatible: nil,
            goodWithKids: true,
            bio: "Energetic and loving puppy ready for adventures. Bella is great with kids and loves playing in the park.",
            energy: .high,
            apartmentFriendly: false
        ),
        Pet(
            id: "sample-4",
            name: "Whiskers",
            species: "cat",
            primaryBreed: "Persian",
            secondaryBreed: nil,
            age: "senior",
            sexRaw: "m",
            size: "m",
            city: "San Francisco",
            state: "CA",
            thumbnailImageURL: URL(string: "https://images.unsplash.com/photo-1574158622682-e40e69881006?auto=format&fit=crop&w=1400&q=80"),
            largeImageURL: URL(string: "https://images.unsplash.com/photo-1574158622682-e40e69881006?auto=format&fit=crop&w=1400&q=80"),
            allImageURLs: [
                URL(string: "https://images.unsplash.com/photo-1574158622682-e40e69881006?auto=format&fit=crop&w=1400&q=80")!,
                URL(string: "https://images.unsplash.com/photo-1513245543132-31f507417b26?auto=format&fit=crop&w=1400&q=80")!
            ],
            detailsURL: URL(string: "https://www.petfinder.com"),
            specialNeeds: false,
            purebred: true,
            bondedPair: false,
            spayedNeutered: nil,
            vaccinated: nil,
            dogsCompatible: nil,
            catsCompatible: nil,
            goodWithKids: false,
            bio: "Gentle and calm senior cat looking for a quiet home. Whiskers enjoys lounging and gentle pets.",
            energy: .low,
            apartmentFriendly: true
        ),
        Pet(
            id: "sample-5",
            name: "Max",
            species: "dog",
            primaryBreed: "German Shepherd",
            secondaryBreed: nil,
            age: "adult",
            sexRaw: "m",
            size: "l",
            city: "Denver",
            state: "CO",
            thumbnailImageURL: URL(string: "https://images.unsplash.com/photo-1583337130417-3346a1be7dee?auto=format&fit=crop&w=1400&q=80"),
            largeImageURL: URL(string: "https://images.unsplash.com/photo-1583337130417-3346a1be7dee?auto=format&fit=crop&w=1400&q=80"),
            allImageURLs: [
                URL(string: "https://images.unsplash.com/photo-1583337130417-3346a1be7dee?auto=format&fit=crop&w=1400&q=80")!,
                URL(string: "https://images.unsplash.com/photo-1551717743-49959800b1f6?auto=format&fit=crop&w=1400&q=80")!
            ],
            detailsURL: URL(string: "https://www.petfinder.com"),
            specialNeeds: false,
            purebred: false,
            bondedPair: false,
            spayedNeutered: nil,
            vaccinated: nil,
            dogsCompatible: nil,
            catsCompatible: nil,
            goodWithKids: true,
            bio: "Loyal and protective companion. Max is well-trained and loves outdoor activities like hiking.",
            energy: .high,
            apartmentFriendly: false
        ),
        Pet(
            id: "sample-6",
            name: "Luna",
            species: "cat",
            primaryBreed: "Siamese",
            secondaryBreed: nil,
            age: "young",
            sexRaw: "f",
            size: "s",
            city: "Miami",
            state: "FL",
            thumbnailImageURL: URL(string: "https://images.unsplash.com/photo-1570018144715-4311034789cd?auto=format&fit=crop&w=1400&q=80"),
            largeImageURL: URL(string: "https://images.unsplash.com/photo-1570018144715-4311034789cd?auto=format&fit=crop&w=1400&q=80"),
            allImageURLs: [
                URL(string: "https://images.unsplash.com/photo-1570018144715-4311034789cd?auto=format&fit=crop&w=1400&q=80")!,
                URL(string: "https://images.unsplash.com/photo-1559235038-1b0f1195aa55?auto=format&fit=crop&w=1400&q=80")!
            ],
            detailsURL: URL(string: "https://www.petfinder.com"),
            specialNeeds: false,
            purebred: true,
            bondedPair: false,
            spayedNeutered: nil,
            vaccinated: nil,
            dogsCompatible: nil,
            catsCompatible: nil,
            goodWithKids: true,
            bio: "Vocal and social cat who loves attention. Luna is playful and gets along well with other pets.",
            energy: .medium,
            apartmentFriendly: true
        ),
        Pet(
            id: "sample-7",
            name: "Charlie",
            species: "dog",
            primaryBreed: "Beagle",
            secondaryBreed: nil,
            age: "adult",
            sexRaw: "m",
            size: "m",
            city: "Boston",
            state: "MA",
            thumbnailImageURL: URL(string: "https://images.unsplash.com/photo-1505628346881-b72b27e84530?auto=format&fit=crop&w=1400&q=80"),
            largeImageURL: URL(string: "https://images.unsplash.com/photo-1505628346881-b72b27e84530?auto=format&fit=crop&w=1400&q=80"),
            allImageURLs: [
                URL(string: "https://images.unsplash.com/photo-1505628346881-b72b27e84530?auto=format&fit=crop&w=1400&q=80")!,
                URL(string: "https://images.unsplash.com/photo-1534361960057-19889c9383e8?auto=format&fit=crop&w=1400&q=80")!
            ],
            detailsURL: URL(string: "https://www.petfinder.com"),
            specialNeeds: false,
            purebred: false,
            bondedPair: false,
            spayedNeutered: nil,
            vaccinated: nil,
            dogsCompatible: nil,
            catsCompatible: nil,
            goodWithKids: true,
            bio: "Friendly and curious beagle with a great nose. Charlie loves sniffing around and making new friends.",
            energy: .medium,
            apartmentFriendly: true
        ),
        Pet(
            id: "sample-8",
            name: "Sophie",
            species: "cat",
            primaryBreed: "Maine Coon",
            secondaryBreed: nil,
            age: "adult",
            sexRaw: "f",
            size: "l",
            city: "Chicago",
            state: "IL",
            thumbnailImageURL: URL(string: "https://images.unsplash.com/photo-1559235038-1b0f1195aa55?auto=format&fit=crop&w=1400&q=80"),
            largeImageURL: URL(string: "https://images.unsplash.com/photo-1559235038-1b0f1195aa55?auto=format&fit=crop&w=1400&q=80"),
            allImageURLs: [
                URL(string: "https://images.unsplash.com/photo-1559235038-1b0f1195aa55?auto=format&fit=crop&w=1400&q=80")!,
                URL(string: "https://images.unsplash.com/photo-1513245543132-31f507417b26?auto=format&fit=crop&w=1400&q=80")!
            ],
            detailsURL: URL(string: "https://www.petfinder.com"),
            specialNeeds: false,
            purebred: false,
            bondedPair: false,
            spayedNeutered: nil,
            vaccinated: nil,
            dogsCompatible: nil,
            catsCompatible: nil,
            goodWithKids: true,
            bio: "Gentle giant with a fluffy coat. Sophie is calm and affectionate, perfect for families.",
            energy: .low,
            apartmentFriendly: true
        ),
        Pet(
            id: "sample-9",
            name: "Rocky",
            species: "dog",
            primaryBreed: "Bulldog",
            secondaryBreed: nil,
            age: "adult",
            sexRaw: "m",
            size: "m",
            city: "Nashville",
            state: "TN",
            thumbnailImageURL: URL(string: "https://images.unsplash.com/photo-1551717743-49959800b1f6?auto=format&fit=crop&w=1400&q=80"),
            largeImageURL: URL(string: "https://images.unsplash.com/photo-1551717743-49959800b1f6?auto=format&fit=crop&w=1400&q=80"),
            allImageURLs: [
                URL(string: "https://images.unsplash.com/photo-1551717743-49959800b1f6?auto=format&fit=crop&w=1400&q=80")!,
                URL(string: "https://images.unsplash.com/photo-1534361960057-19889c9383e8?auto=format&fit=crop&w=1400&q=80")!
            ],
            detailsURL: URL(string: "https://www.petfinder.com"),
            specialNeeds: false,
            purebred: false,
            bondedPair: false,
            spayedNeutered: nil,
            vaccinated: nil,
            dogsCompatible: nil,
            catsCompatible: nil,
            goodWithKids: true,
            bio: "Chill and laid-back companion. Rocky enjoys short walks and lots of cuddle time on the couch.",
            energy: .low,
            apartmentFriendly: true
        ),
        Pet(
            id: "sample-10",
            name: "Zoe",
            species: "cat",
            primaryBreed: "Russian Blue",
            secondaryBreed: nil,
            age: "young",
            sexRaw: "f",
            size: "s",
            city: "Phoenix",
            state: "AZ",
            thumbnailImageURL: URL(string: "https://images.unsplash.com/photo-1513245543132-31f507417b26?auto=format&fit=crop&w=1400&q=80"),
            largeImageURL: URL(string: "https://images.unsplash.com/photo-1513245543132-31f507417b26?auto=format&fit=crop&w=1400&q=80"),
            allImageURLs: [
                URL(string: "https://images.unsplash.com/photo-1513245543132-31f507417b26?auto=format&fit=crop&w=1400&q=80")!,
                URL(string: "https://images.unsplash.com/photo-1574158622682-e40e69881006?auto=format&fit=crop&w=1400&q=80")!
            ],
            detailsURL: URL(string: "https://www.petfinder.com"),
            specialNeeds: false,
            purebred: true,
            bondedPair: false,
            spayedNeutered: nil,
            vaccinated: nil,
            dogsCompatible: nil,
            catsCompatible: nil,
            goodWithKids: true,
            bio: "Elegant and intelligent cat with a silvery coat. Zoe is playful but also enjoys quiet moments.",
            energy: .medium,
            apartmentFriendly: true
        ),
        Pet(
            id: "sample-11",
            name: "Daisy",
            species: "dog",
            primaryBreed: "Cocker Spaniel",
            secondaryBreed: nil,
            age: "puppy",
            sexRaw: "f",
            size: "m",
            city: "Atlanta",
            state: "GA",
            thumbnailImageURL: URL(string: "https://images.unsplash.com/photo-1583337130417-3346a1be7dee?auto=format&fit=crop&w=1400&q=80"),
            largeImageURL: URL(string: "https://images.unsplash.com/photo-1583337130417-3346a1be7dee?auto=format&fit=crop&w=1400&q=80"),
            allImageURLs: [
                URL(string: "https://images.unsplash.com/photo-1583337130417-3346a1be7dee?auto=format&fit=crop&w=1400&q=80")!,
                URL(string: "https://images.unsplash.com/photo-1552053831-71594a27632d?auto=format&fit=crop&w=1400&q=80")!
            ],
            detailsURL: URL(string: "https://www.petfinder.com"),
            specialNeeds: false,
            purebred: false,
            bondedPair: false,
            spayedNeutered: nil,
            vaccinated: nil,
            dogsCompatible: nil,
            catsCompatible: nil,
            goodWithKids: true,
            bio: "Sweet and energetic puppy with wavy fur. Daisy loves playing fetch and learning new tricks.",
            energy: .high,
            apartmentFriendly: true
        ),
        Pet(
            id: "sample-12",
            name: "Oliver",
            species: "cat",
            primaryBreed: "British Shorthair",
            secondaryBreed: nil,
            age: "adult",
            sexRaw: "m",
            size: "m",
            city: "New York",
            state: "NY",
            thumbnailImageURL: URL(string: "https://images.unsplash.com/photo-1494256997604-768d1f608cac?auto=format&fit=crop&w=1400&q=80"),
            largeImageURL: URL(string: "https://images.unsplash.com/photo-1494256997604-768d1f608cac?auto=format&fit=crop&w=1400&q=80"),
            allImageURLs: [
                URL(string: "https://images.unsplash.com/photo-1494256997604-768d1f608cac?auto=format&fit=crop&w=1400&q=80")!,
                URL(string: "https://images.unsplash.com/photo-1518791841217-8f162f1e1131?auto=format&fit=crop&w=1400&q=80")!
            ],
            detailsURL: URL(string: "https://www.petfinder.com"),
            specialNeeds: false,
            purebred: true,
            bondedPair: false,
            spayedNeutered: nil,
            vaccinated: nil,
            dogsCompatible: nil,
            catsCompatible: nil,
            goodWithKids: true,
            bio: "Calm and dignified cat with a round face. Oliver enjoys watching the world from his favorite window.",
            energy: .low,
            apartmentFriendly: true
        )
    ]
}

