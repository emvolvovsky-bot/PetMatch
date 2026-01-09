//
//  PetDeckViewModel.swift
//  PetMatch
//

import Foundation
import SwiftUI
import CoreLocation
import MapKit

extension Array {
    /// Split array into chunks of specified size
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

@MainActor
final class PetDeckViewModel: ObservableObject {
    @Published private(set) var deck: [Pet] = []
    @Published private(set) var allPets: [Pet] = [] // Store all loaded pets
    @Published private(set) var liked: [Pet] = []
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published private(set) var hasNoPetsAvailable: Bool = false // Track if initial load returned no pets
    @Published private(set) var totalSwipes: Int = 0
    @Published private(set) var rewardMilestone: Int = 0
    @Published var filters: PetFilters = PetFilters() {
        didSet {
            applyFilters()
        }
    }

    let repository: PetRepository
    private let rewardMilestoneSize = 12
    private var petCoordinates: [String: CLLocationCoordinate2D] = [:]
    private let locationManager = LocationManager()
    private var geocodingInProgress: Set<String> = [] // Track pets being geocoded
    private var geocodeTask: Task<Void, Never>? // Single task for batch geocoding
    private let maxConcurrentGeocoding = 5 // Limit concurrent geocoding operations
    
    // Make coordinate cache accessible for map view
    func setCoordinate(_ coordinate: CLLocationCoordinate2D, forPetId petId: String) {
        petCoordinates[petId] = coordinate
    }

    init(repository: PetRepository? = nil) {
        if let repository {
            self.repository = repository
        } else {
            // Try DistributorPetRepository first (CSV API)
            let distributorRepo = DistributorPetRepository()
            
            // Build a Petfinder repository from runtime configuration (no secrets in source control).
            do {
                let config = try PetfinderConfig.fromRuntimeConfiguration()
                let client = PetfinderClient(config: config)
                let petfinderRepo = PetfinderPetRepository(client: client)
                
                // Use DistributorPetRepository as primary, Petfinder as secondary, Sample as final fallback
                self.repository = FallbackPetRepository(
                    primary: FallbackPetRepository(
                        primary: distributorRepo,
                        fallback: petfinderRepo
                    ),
                    fallback: SamplePetRepository()
                )
            } catch {
                // If Petfinder is not configured, use DistributorPetRepository with Sample fallback
                self.repository = FallbackPetRepository(
                    primary: distributorRepo,
                    fallback: SamplePetRepository()
                )
                self.errorMessage = nil
            }
        }

        Task { await reload() }
    }

    func currentTopPets(limit: Int = 3) -> [Pet] {
        Array(deck.prefix(limit))
    }

    func swipe(_ pet: Pet, direction: SwipeDirection) {
        guard let index = deck.firstIndex(of: pet) else { return }
        let removed = deck.remove(at: index)

        totalSwipes += 1
        if totalSwipes > 0, totalSwipes % rewardMilestoneSize == 0 {
            rewardMilestone += 1
        }

        if direction == .like {
            liked.insert(removed, at: 0)
        } else {
        }

        maybeLoadMore()
    }

    func resetDeck() {
        Task { await reload() }
    }
    
    @MainActor
    func shuffleDeck() {
        guard !deck.isEmpty else {
            // If deck is empty, reload first (filters are preserved via applyFilters())
            Task { await reload() }
            return
        }
        // Shuffle the deck without affecting filters
        deck.shuffle()
    }

    func removeLike(_ pet: Pet) {
        liked.removeAll { $0.id == pet.id }
    }

    @MainActor
    func reload() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        hasNoPetsAvailable = false
        defer { isLoading = false }

        do {
            // Load fresh pets from repository (filters are preserved and applied below)
            allPets = try await repository.loadInitialPets()
            // Check if initial load returned no pets
            if allPets.isEmpty {
                hasNoPetsAvailable = true
                deck = []
            } else {
                hasNoPetsAvailable = false
                // Apply current filters to the newly loaded pets (filters are preserved)
                applyFilters()
            }
        } catch {
            (repository as? PetfinderPetRepository)?.noteThrottleIfNeeded(error)
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            allPets = []
            deck = []
            hasNoPetsAvailable = false
        }
    }

    var rewardProgress: Double {
        guard rewardMilestoneSize > 0 else { return 0 }
        let step = totalSwipes % rewardMilestoneSize
        return Double(step) / Double(rewardMilestoneSize)
    }

    private func maybeLoadMore() {
        guard deck.count <= 5 else { return }
        guard !isLoading else { return }

        Task { @MainActor in
            isLoading = true
            defer { isLoading = false }
            do {
                let more = try await repository.loadMorePetsIfAvailable()
                allPets.append(contentsOf: more)
                // If we successfully loaded more pets, reset the no pets flag
                if !more.isEmpty {
                    hasNoPetsAvailable = false
                }
                applyFilters()
            } catch {
                (repository as? PetfinderPetRepository)?.noteThrottleIfNeeded(error)
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }
    
    /// Apply filters to allPets and update deck
    private func applyFilters() {
        // Reset hasNoPetsAvailable when applying filters (new search criteria)
        hasNoPetsAvailable = false
        
        deck = allPets.filter { pet in
            // Filter out pets with placeholder names
            if pet.name.lowercased() == "meet me" || pet.name.trimmingCharacters(in: .whitespaces).isEmpty {
                return false
            }
            
            // Species filter
            if !filters.species.contains(pet.species.lowercased()) {
                return false
            }
            
            // Breed filter
            if !filters.breeds.isEmpty {
                let petBreeds = [pet.primaryBreed, pet.secondaryBreed].compactMap { $0 }
                let matches = petBreeds.contains { breed in
                    filters.breeds.contains { selectedBreed in
                        breed.localizedCaseInsensitiveContains(selectedBreed) ||
                        selectedBreed.localizedCaseInsensitiveContains(breed)
                    }
                }
                if !matches {
                    return false
                }
            }
            
            // Age filter
            if !filters.ages.isEmpty {
                if !filters.ages.contains(pet.age.lowercased()) {
                    return false
                }
            }
            
            // Size filter
            if !filters.sizes.isEmpty {
                guard let petSize = pet.size?.lowercased() else { return false }
                if !filters.sizes.contains(petSize) {
                    return false
                }
            }
            
            // Gender filter
            if !filters.genders.isEmpty {
                guard let petGender = pet.sexRaw?.lowercased() else { return false }
                if !filters.genders.contains(petGender) {
                    return false
                }
            }
            
            // Vaccinated filter
            if let vaccinated = filters.vaccinated {
                if pet.vaccinated != vaccinated {
                    return false
                }
            }
            
            // Color filter (check bio and breed for color mentions)
            if !filters.colors.isEmpty {
                let petText = "\(pet.primaryBreed) \(pet.secondaryBreed ?? "") \(pet.bio)".lowercased()
                let matches = filters.colors.contains { color in
                    petText.localizedCaseInsensitiveContains(color)
                }
                if !matches {
                    return false
                }
            }
            
            // Compatibility filters
            if let goodWithKids = filters.goodWithKids {
                if pet.goodWithKids != goodWithKids {
                    return false
                }
            }
            
            if let dogsCompatible = filters.dogsCompatible {
                if pet.dogsCompatible != dogsCompatible {
                    return false
                }
            }
            
            if let catsCompatible = filters.catsCompatible {
                if pet.catsCompatible != catsCompatible {
                    return false
                }
            }
            
            // Location filter
            if filters.hasLocationFilter,
               let filterLat = filters.locationLatitude,
               let filterLon = filters.locationLongitude,
               let radiusMiles = filters.locationRadiusMiles {
                // Check if we have coordinates for this pet
                if let petCoord = petCoordinates[pet.id] {
                    let filterCoord = CLLocationCoordinate2D(latitude: filterLat, longitude: filterLon)
                    let location1 = CLLocation(latitude: filterCoord.latitude, longitude: filterCoord.longitude)
                    let location2 = CLLocation(latitude: petCoord.latitude, longitude: petCoord.longitude)
                    let distanceInMeters = location1.distance(from: location2)
                    let distanceInMiles = distanceInMeters / 1609.34
                    
                    if distanceInMiles > radiusMiles {
                        return false
                    }
                } else {
                    // When location filtering is active, don't include pets without coordinates
                    // Queue for geocoding, but exclude from deck until coordinates are available
                    queueGeocodeIfNeeded(pet)
                    return false
                }
            }
            
            return true
        }
        
        // If location filtering is active and deck is empty, set hasNoPetsAvailable
        if filters.hasLocationFilter && deck.isEmpty {
            hasNoPetsAvailable = true
        }
    }
    
    /// Queue a pet for geocoding (batched to limit concurrent operations)
    private func queueGeocodeIfNeeded(_ pet: Pet) {
        // Skip if already cached or in progress
        guard petCoordinates[pet.id] == nil,
              !geocodingInProgress.contains(pet.id) else { return }
        
        geocodingInProgress.insert(pet.id)
        
        // Cancel existing geocode task if filter changes rapidly
        geocodeTask?.cancel()
        
        // Create new batch geocoding task with delay to batch multiple requests
        geocodeTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            
            // Small delay to batch multiple geocoding requests
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            guard !Task.isCancelled else { return }
            
            // Collect all pets that need geocoding
            let petsToGeocode = self.allPets.filter { pet in
                self.petCoordinates[pet.id] == nil &&
                self.geocodingInProgress.contains(pet.id)
            }
            
            guard !petsToGeocode.isEmpty else { return }
            
            // Process in batches to limit concurrent operations
            var updated = false
            for chunk in petsToGeocode.chunked(into: self.maxConcurrentGeocoding) {
                guard !Task.isCancelled else { break }
                
                // Process chunk concurrently
                await withTaskGroup(of: (String, CLLocationCoordinate2D?).self) { group in
                    for pet in chunk {
                        group.addTask { [weak self] in
                            guard let self = self,
                                  let coordinate = await self.locationManager.geocode(
                                    city: pet.city,
                                    state: pet.state
                                  ) else {
                                return (pet.id, nil)
                            }
                            return (pet.id, coordinate)
                        }
                    }
                    
                    // Collect results
                    for await (petId, coordinate) in group {
                        guard let coordinate = coordinate else { continue }
                        if self.petCoordinates[petId] == nil {
                            self.petCoordinates[petId] = coordinate
                            updated = true
                        }
                        self.geocodingInProgress.remove(petId)
                    }
                }
            }
            
            // Re-apply filters only once after batch completes
            if updated && !Task.isCancelled {
                // Check if we have any pets in range after geocoding
                let hasPetsInRange = self.allPets.contains { pet in
                    guard self.filters.hasLocationFilter,
                          let filterLat = self.filters.locationLatitude,
                          let filterLon = self.filters.locationLongitude,
                          let radiusMiles = self.filters.locationRadiusMiles,
                          let petCoord = self.petCoordinates[pet.id] else {
                        return false
                    }
                    let filterCoord = CLLocationCoordinate2D(latitude: filterLat, longitude: filterLon)
                    let location1 = CLLocation(latitude: filterCoord.latitude, longitude: filterCoord.longitude)
                    let location2 = CLLocation(latitude: petCoord.latitude, longitude: petCoord.longitude)
                    let distanceInMeters = location1.distance(from: location2)
                    let distanceInMiles = distanceInMeters / 1609.34
                    return distanceInMiles <= radiusMiles
                }
                
                // If no pets in range after geocoding, set hasNoPetsAvailable
                if self.filters.hasLocationFilter && !hasPetsInRange {
                    self.hasNoPetsAvailable = true
                }
                
                self.applyFilters()
            }
        }
    }
    
    /// Geocode a pet's location if needed (legacy method, now uses queueGeocodeIfNeeded)
    private func geocodePetIfNeeded(_ pet: Pet) async {
        queueGeocodeIfNeeded(pet)
    }
    
    /// Get all available breeds from loaded pets
    var availableBreeds: [String] {
        let breeds = allPets.flatMap { [$0.primaryBreed, $0.secondaryBreed].compactMap { $0 } }
        return Array(Set(breeds)).sorted()
    }
    
    /// Get all available colors from loaded pets (extract from breed/bio)
    var availableColors: [String] {
        let commonColors = ["Black", "White", "Brown", "Gray", "Golden", "Orange", "Tabby", "Tricolor", "Brindle", "Cream"]
        return commonColors.sorted()
    }
    
    /// Get coordinate for a pet (for map view)
    func coordinate(for pet: Pet) -> CLLocationCoordinate2D? {
        return petCoordinates[pet.id]
    }
    
    /// Preload coordinates for all pets in deck (for map view)
    func preloadPetCoordinates() async {
        for pet in deck {
            if petCoordinates[pet.id] == nil {
                if let coordinate = await locationManager.geocode(city: pet.city, state: pet.state) {
                    petCoordinates[pet.id] = coordinate
                }
            }
        }
    }
    
    /// Load all available pets (for map view)
    /// This ensures all pets are loaded into allPets
    func loadAllPets() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Start with initial pets
            var loadedPets = try await repository.loadInitialPets()
            
            // Keep loading until no more pets are available
            while true {
                let more = try await repository.loadMorePetsIfAvailable()
                if more.isEmpty {
                    break
                }
                loadedPets.append(contentsOf: more)
            }
            
            allPets = loadedPets
            applyFilters()
        } catch {
            (repository as? PetfinderPetRepository)?.noteThrottleIfNeeded(error)
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
    
    /// Preload coordinates for all pets (for map view)
    /// This processes pets in batches to avoid overwhelming the geocoding service
    func preloadAllPetCoordinates() async {
        // Ensure all pets are loaded first
        if allPets.count < 100 {
            await loadAllPets()
        }
        
        let petsToGeocode = allPets.filter { petCoordinates[$0.id] == nil }
        
        // Process in batches to avoid rate limiting
        let batchSize = 10
        for chunk in petsToGeocode.chunked(into: batchSize) {
            await withTaskGroup(of: (String, CLLocationCoordinate2D?).self) { group in
                for pet in chunk {
                    group.addTask { [locationManager] in
                        let coordinate = await locationManager.geocode(city: pet.city, state: pet.state)
                        return (pet.id, coordinate)
                    }
                }
                
                // Collect results and update coordinate cache
                for await (petId, coordinate) in group {
                    guard let coordinate = coordinate else { continue }
                    petCoordinates[petId] = coordinate
                }
            }
            
            // Small delay between batches to avoid rate limiting
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
    }
}

