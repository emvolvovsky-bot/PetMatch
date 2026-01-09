import Foundation

@MainActor
final class PetDetailViewModel: ObservableObject {
    @Published private(set) var pet: Pet
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let repository: PetRepository

    init(pet: Pet, repository: PetRepository) {
        self.pet = pet
        self.repository = repository
    }

    func loadDetails() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let details = try await repository.loadPetDetails(petID: pet.id)
            // Only update if we got the correct pet (same ID)
            // This prevents replacing correct pet data with wrong pet data
            if details.id == pet.id {
                pet = pet.enriched(with: details)
            }
            // If IDs don't match, keep the original pet data (don't update)
        } catch {
            // If loading fails (e.g., pet not found), keep the original pet data
            // This is fine for DistributorPetRepository since we already have all data from CSV
            // Optional throttle backoff support.
            (repository as? PetfinderPetRepository)?.noteThrottleIfNeeded(error)
            // Don't show error for 404s from DistributorPetRepository - we already have the data
            if !(error.localizedDescription.contains("Pet not found") && repository is DistributorPetRepository) {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }
}

extension Pet {
    func enriched(with details: Pet) -> Pet {
        Pet(
            id: id,
            name: details.name.isEmpty ? name : details.name,
            species: details.species.isEmpty ? species : details.species,
            primaryBreed: details.primaryBreed.isEmpty ? primaryBreed : details.primaryBreed,
            secondaryBreed: details.secondaryBreed ?? secondaryBreed,
            age: details.age.isEmpty ? age : details.age,
            sexRaw: details.sexRaw ?? sexRaw,
            size: details.size ?? size,
            city: details.city ?? city,
            state: details.state ?? state,
            thumbnailImageURL: details.thumbnailImageURL ?? thumbnailImageURL,
            largeImageURL: details.largeImageURL ?? largeImageURL,
            allImageURLs: details.allImageURLs.isEmpty ? allImageURLs : details.allImageURLs,
            detailsURL: details.detailsURL ?? detailsURL,
            specialNeeds: details.specialNeeds || specialNeeds,
            purebred: details.purebred || purebred,
            bondedPair: details.bondedPair || bondedPair,
            spayedNeutered: details.spayedNeutered ?? spayedNeutered,
            vaccinated: details.vaccinated ?? vaccinated,
            dogsCompatible: details.dogsCompatible ?? dogsCompatible,
            catsCompatible: details.catsCompatible ?? catsCompatible,
            goodWithKids: details.goodWithKids ?? goodWithKids,
            bio: details.bio.isEmpty ? bio : details.bio,
            energy: energy, // keep UI-only fields stable
            apartmentFriendly: apartmentFriendly
        )
    }
}


