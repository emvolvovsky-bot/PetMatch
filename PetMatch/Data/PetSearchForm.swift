import Foundation

/// Provider-agnostic search metadata (types, breeds, ages, sizes, etc.).
///
/// The current UI doesn’t expose filters yet, but this keeps the data layer swappable.
struct PetSearchForm: Sendable, Hashable {
    struct Option: Sendable, Hashable, Identifiable {
        var id: String { value }
        let label: String
        let value: String
    }

    var types: [Option] = []
    var breeds: [Option] = []
    var ages: [Option] = []
    var sizes: [Option] = []
    var genders: [Option] = []
    var colors: [Option] = []
    var distances: [Option] = []
}












