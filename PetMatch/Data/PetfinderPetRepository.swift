import Foundation

final class PetfinderPetRepository: PetRepository {
    private let client: PetfinderClient

    private var request = PetfinderAnimalsRequest()
    private var nextPage: Int = 1
    private var throttledUntil: Date?

    init(client: PetfinderClient) {
        self.client = client
    }

    func loadSearchForm(species: String) async throws -> PetSearchForm {
        // Petfinder supports /types and /types/{type}/breeds, but the app doesn’t expose filters yet.
        // Return an empty model for now.
        PetSearchForm()
    }

    func loadInitialPets() async throws -> [Pet] {
        try enforceThrottle()
        nextPage = 1
        request.page = nextPage
        let dto = try await client.fetchAnimals(request: request)
        nextPage += 1
        
        // Filter out invalid pets (those with null names) and return only valid pets
        let validPets = dto.animals
            .filter { $0.name != nil && !$0.name!.isEmpty }
            .map(mapAnimal)
        
        return validPets
    }

    func loadMorePetsIfAvailable() async throws -> [Pet] {
        try enforceThrottle()
        request.page = nextPage
        let dto = try await client.fetchAnimals(request: request)
        nextPage += 1
        
        // Filter out invalid pets (those with null names) and return only valid pets
        let validPets = dto.animals
            .filter { $0.name != nil && !$0.name!.isEmpty }
            .map(mapAnimal)
        
        return validPets
    }

    func loadPetDetails(petID: String) async throws -> Pet {
        try enforceThrottle()
        let dto = try await client.fetchAnimalDetails(id: petID)
        return mapAnimal(dto.animal)
    }

    // MARK: - Throttling

    private func enforceThrottle() throws {
        if let throttledUntil, Date() < throttledUntil {
            throw PetfinderError.throttled(retryAfter: throttledUntil.timeIntervalSinceNow)
        }
    }

    private func applyThrottle(retryAfter: TimeInterval?) {
        let delay = max(10, min(retryAfter ?? 30, 120))
        throttledUntil = Date().addingTimeInterval(delay)
    }

    func noteThrottleIfNeeded(_ error: Error) {
        guard case let PetfinderError.throttled(retryAfter) = error else { return }
        applyThrottle(retryAfter: retryAfter)
    }

    // MARK: - Mapping

    private func mapAnimal(_ dto: PetfinderAnimalDTO) -> Pet {
        let images: [URL] = (dto.photos ?? []).compactMap { photo in
            // Prefer full/large, fall back.
            let s = photo.full ?? photo.large ?? photo.medium ?? photo.small
            return s.flatMap(URL.init(string:))
        }

        let thumbnail = (dto.photos?.first?.medium ?? dto.photos?.first?.small).flatMap(URL.init(string:))
        let large = (dto.photos?.first?.large ?? dto.photos?.first?.full).flatMap(URL.init(string:))

        let primaryBreed = dto.breeds?.primary ?? dto.breeds?.secondary ?? "Unknown breed"
        let secondaryBreed = dto.breeds?.secondary

        let city = dto.contact?.address?.city
        let state = dto.contact?.address?.state

        let specialNeeds = dto.attributes?.specialNeeds ?? false
        let purebred = (dto.breeds?.mixed == false) && (dto.breeds?.unknown == false)
        let bondedPair = false

        let species = dto.type ?? dto.species ?? "Unknown"

        return Pet(
            id: String(dto.id),
            name: dto.name ?? "Unknown",
            species: species,
            primaryBreed: primaryBreed,
            secondaryBreed: secondaryBreed,
            age: (dto.age ?? "Unknown").lowercased(),
            sexRaw: normalizeGender(dto.gender),
            size: dto.size,
            city: city,
            state: state,
            thumbnailImageURL: thumbnail,
            largeImageURL: large,
            allImageURLs: images.isEmpty ? [large, thumbnail].compactMap { $0 } : images,
            detailsURL: dto.url.flatMap(URL.init(string:)),
            specialNeeds: specialNeeds,
            purebred: purebred,
            bondedPair: bondedPair,
            spayedNeutered: dto.attributes?.spayedNeutered,
            vaccinated: nil, // Petfinder API doesn't provide this
            dogsCompatible: dto.environment?.dogs,
            catsCompatible: dto.environment?.cats,
            goodWithKids: dto.environment?.children, // Preserve nil for Unknown state
            bio: "Tap to see more photos and details.",
            energy: .medium,
            apartmentFriendly: false
        )
    }

    private func normalizeGender(_ gender: String?) -> String? {
        guard let g = gender?.lowercased() else { return nil }
        if g == "male" { return "m" }
        if g == "female" { return "f" }
        return nil
    }
}










