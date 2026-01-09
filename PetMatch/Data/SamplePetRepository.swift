import Foundation

/// Local/demo repository that returns the original placeholder pets and photos.
final class SamplePetRepository: PetRepository {
    private var rotation: Int = 0

    func loadInitialPets() async throws -> [Pet] {
        rotation = 0
        return SamplePets.all.shuffled()
    }

    func loadMorePetsIfAvailable() async throws -> [Pet] {
        // Keep returning a shuffled set to simulate pagination.
        rotation += 1
        return SamplePets.all.shuffled()
    }

    func loadPetDetails(petID: String) async throws -> Pet {
        SamplePets.all.first(where: { $0.id == petID }) ?? SamplePets.all.first!
    }

    func loadSearchForm(species: String) async throws -> PetSearchForm {
        PetSearchForm()
    }
}

/// Wraps a primary repository with a fallback that is used if the primary fails.
final class FallbackPetRepository: PetRepository {
    private let primary: PetRepository
    private let fallback: PetRepository

    init(primary: PetRepository, fallback: PetRepository) {
        self.primary = primary
        self.fallback = fallback
    }

    func loadInitialPets() async throws -> [Pet] {
        do { return try await primary.loadInitialPets() }
        catch { return try await fallback.loadInitialPets() }
    }

    func loadMorePetsIfAvailable() async throws -> [Pet] {
        do { return try await primary.loadMorePetsIfAvailable() }
        catch { return try await fallback.loadMorePetsIfAvailable() }
    }

    func loadPetDetails(petID: String) async throws -> Pet {
        do { return try await primary.loadPetDetails(petID: petID) }
        catch { return try await fallback.loadPetDetails(petID: petID) }
    }

    func loadSearchForm(species: String) async throws -> PetSearchForm {
        do { return try await primary.loadSearchForm(species: species) }
        catch { return try await fallback.loadSearchForm(species: species) }
    }
}












