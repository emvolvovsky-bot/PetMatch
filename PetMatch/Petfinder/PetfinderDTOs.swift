import Foundation

// MARK: - OAuth

struct PetfinderTokenResponseDTO: Decodable, Sendable {
    let tokenType: String
    let expiresIn: Int
    let accessToken: String
}

// MARK: - /animals

struct PetfinderAnimalsResponseDTO: Decodable, Sendable {
    let animals: [PetfinderAnimalDTO]
}

struct PetfinderAnimalDTO: Decodable, Sendable {
    let id: Int
    let name: String?
    let type: String?
    let species: String?
    let age: String?
    let gender: String?
    let size: String?
    let url: String?

    let breeds: PetfinderBreedsDTO?
    let colors: PetfinderColorsDTO?
    let contact: PetfinderContactDTO?
    let photos: [PetfinderPhotoDTO]?
    let attributes: PetfinderAttributesDTO?
    let environment: PetfinderEnvironmentDTO?
}

struct PetfinderBreedsDTO: Decodable, Sendable {
    let primary: String?
    let secondary: String?
    let mixed: Bool?
    let unknown: Bool?
}

struct PetfinderColorsDTO: Decodable, Sendable {
    let primary: String?
    let secondary: String?
    let tertiary: String?
}

struct PetfinderContactDTO: Decodable, Sendable {
    let address: PetfinderAddressDTO?
}

struct PetfinderAddressDTO: Decodable, Sendable {
    let city: String?
    let state: String?
    let postcode: String?
    let country: String?
}

struct PetfinderPhotoDTO: Decodable, Sendable {
    let small: String?
    let medium: String?
    let large: String?
    let full: String?
}

struct PetfinderAttributesDTO: Decodable, Sendable {
    let spayedNeutered: Bool?
    let houseTrained: Bool?
    let specialNeeds: Bool?
}

struct PetfinderEnvironmentDTO: Decodable, Sendable {
    let children: Bool?
    let dogs: Bool?
    let cats: Bool?
}

// MARK: - /animals/{id}

struct PetfinderAnimalDetailsResponseDTO: Decodable, Sendable {
    let animal: PetfinderAnimalDTO
}












