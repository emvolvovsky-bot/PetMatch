import Foundation

protocol PetRepository {
    func loadInitialPets() async throws -> [Pet]
    func loadMorePetsIfAvailable() async throws -> [Pet]
    func loadPetDetails(petID: String) async throws -> Pet

    /// Optional: used when/if the app adds a filter UI.
    func loadSearchForm(species: String) async throws -> PetSearchForm
}


