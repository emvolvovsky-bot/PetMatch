//
//  PetDetailView.swift
//  PetMatch
//

import SwiftUI
import UIKit

struct PetDetailView: View, Identifiable {
    let id: String
    @StateObject private var viewModel: PetDetailViewModel
    var primaryActionTitle: String?
    var onPrimaryAction: (() -> Void)?

    @State private var currentIndex = 0
    @State private var safariItem: SafariItem?
    @State private var scrollOffset: CGFloat = 0
    @Environment(\.dismiss) private var dismiss

    init(
        pet: Pet,
        repository: PetRepository,
        primaryActionTitle: String? = nil,
        onPrimaryAction: (() -> Void)? = nil
    ) {
        // Use the pet's ID directly to ensure proper view identity
        self.id = pet.id
        _viewModel = StateObject(wrappedValue: PetDetailViewModel(pet: pet, repository: repository))
        self.primaryActionTitle = primaryActionTitle
        self.onPrimaryAction = onPrimaryAction
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Grab bar at the top
                grabBar
                
                ScrollView {
                    GeometryReader { geometry in
                        Color.clear
                            .preference(key: ScrollOffsetPreferenceKey.self, value: geometry.frame(in: .named("scroll")).minY)
                    }
                    .frame(height: 0)
                    
                    VStack(alignment: .leading, spacing: 18) {
                        carousel

                        VStack(alignment: .leading, spacing: 10) {
                            Text(viewModel.pet.name)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(PMColor.textPrimary)
                            Text("\(viewModel.pet.breedDisplay) • \(viewModel.pet.ageDisplay) • \(viewModel.pet.sexDisplay)")
                                .font(.system(size: 17, weight: .regular))
                                .foregroundStyle(PMColor.textSecondary)
                            Text(viewModel.pet.locationDisplay)
                                .font(.system(size: 15, weight: .regular))
                                .foregroundStyle(PMColor.textTertiary)
                        }

                        // Wrapping chips layout
                        WrappingHStack(items: viewModel.pet.chips, spacing: 8) { chip in
                            ChipView(text: chip.label, backgroundHex: chip.background, foregroundHex: chip.foreground)
                        }

                        // Health & Status section - show all fields, including false values
                        if viewModel.pet.hasHealthStatus {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Health & Status")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(PMColor.textPrimary)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    if let spayedNeutered = viewModel.pet.spayedNeutered {
                                        StatusBadge(label: "Spayed/Neutered", isPositive: spayedNeutered)
                                    }
                                    if let vaccinated = viewModel.pet.vaccinated {
                                        StatusBadge(label: "Vaccinated", isPositive: vaccinated)
                                    }
                                    StatusBadge(label: "Special Needs", isPositive: viewModel.pet.specialNeeds)
                                }
                            }
                        }

                        // Compatibility section - show all fields, including unknown (nil) values
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Compatibility")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(PMColor.textPrimary)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                // Show kids compatibility - nil means unknown
                                if let goodWithKids = viewModel.pet.goodWithKids {
                                    StatusBadge(label: "Good with kids", isPositive: goodWithKids)
                                } else {
                                    StatusBadge(label: "Good with kids", isUnknown: true)
                                }
                                
                                // Show dogs compatibility - nil means unknown
                                if let dogsCompatible = viewModel.pet.dogsCompatible {
                                    StatusBadge(label: "Good with dogs", isPositive: dogsCompatible)
                                } else {
                                    StatusBadge(label: "Good with dogs", isUnknown: true)
                                }
                                
                                // Show cats compatibility - nil means unknown
                                if let catsCompatible = viewModel.pet.catsCompatible {
                                    StatusBadge(label: "Good with cats", isPositive: catsCompatible)
                                } else {
                                    StatusBadge(label: "Good with cats", isUnknown: true)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("About")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(PMColor.textPrimary)
                            bioText
                        }

                        if let title = primaryActionTitle, let onPrimaryAction {
                            Button {
                                Haptics.success()
                                onPrimaryAction()
                            } label: {
                                Text(title)
                                    .font(.system(size: 17, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(LinearGradient.primaryPetGradient)
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
                                    .shadow(color: PMColor.coral.opacity(0.35), radius: 18, x: 0, y: 12)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 4)
                        }

                        if let url = viewModel.pet.detailsURL {
                            Button {
                                safariItem = SafariItem(url: url)
                            } label: {
                                Text("View on Petfinder")
                                    .font(.system(size: 17, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(PMColor.secondarySurface)
                                    .foregroundStyle(PMColor.textPrimary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                }
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    scrollOffset = value
                }
            }
            
            // Top-left back button - appears when scrolled down
            VStack {
                HStack {
                    if scrollOffset < -50 {
                        topLeftBackButton
                            .transition(.scale.combined(with: .opacity))
                    }
                    Spacer()
                }
                .padding(.top, 8)
                Spacer()
            }
            .ignoresSafeArea(edges: .top)
        }
        .background(PMColor.background.ignoresSafeArea())
        .task { await viewModel.loadDetails() }
        .sheet(item: $safariItem) { item in
            SafariView(url: item.url, tintColor: UIColor(PMColor.coral))
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: scrollOffset < -100)
    }
    
    private var grabBar: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2.5)
                .fill(PMColor.textTertiary.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .background(PMColor.background)
    }
    
    private var bioText: some View {
        BioTextView(
            text: viewModel.pet.bio.strippingHTML().removingShowMoreText(),
            onURLClick: { url in
                // Handle mailto: and tel: URLs by opening native apps
                if url.scheme == "mailto" || url.scheme == "tel" {
                    UIApplication.shared.open(url)
                } else {
                    // Regular URLs open in Safari
                    safariItem = SafariItem(url: url)
                }
            }
        )
    }

    private var carousel: some View {
        TabView(selection: $currentIndex) {
            ForEach(Array(viewModel.pet.photos.enumerated()), id: \.offset) { index, url in
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ZStack {
                            LinearGradient.supportGradient
                            ProgressView().tint(.white)
                        }
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        ZStack {
                            PMColor.secondarySurface
                            Image(systemName: "pawprint.fill")
                                .font(.system(size: 44, weight: .semibold))
                                .foregroundStyle(PMColor.textTertiary)
                        }
                    @unknown default:
                        Color.gray
                    }
                }
                .tag(index)
                .frame(height: 320)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .shadow(color: Color.black.opacity(0.1), radius: 16, x: 0, y: 12)
                .padding(.horizontal, 4)
            }
        }
        .frame(height: 340)
        .tabViewStyle(.page(indexDisplayMode: .always))
    }
    
    private var backButton: some View {
        Button {
            Haptics.softTap()
            dismiss()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                Text("Back")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(LinearGradient.primaryPetGradient)
            .clipShape(Capsule())
            .shadow(color: PMColor.coral.opacity(0.4), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .padding(.trailing, 20)
        .padding(.bottom, 20)
    }
    
    private var topLeftBackButton: some View {
        Button {
            Haptics.softTap()
            dismiss()
        } label: {
            Text("⤹")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(
                    LinearGradient.primaryPetGradient
                )
                .clipShape(Circle())
                .shadow(color: PMColor.coral.opacity(0.4), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .padding(.leading, 20)
        .safeAreaInset(edge: .top) {
            Color.clear.frame(height: 0)
        }
        .padding(.top, 8)
    }
}

// MARK: - Scroll Offset Preference Key

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#if DEBUG
#Preview {
    PetDetailView(
        pet: SamplePets.all.first!,
        repository: PreviewPetRepository(pets: SamplePets.all),
        primaryActionTitle: "Save to likes",
        onPrimaryAction: {}
    )
}
#endif

private struct SafariItem: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - Bio Text View with Clickable URLs, Emails, and Phone Numbers

private struct BioTextView: View {
    let text: String
    let onURLClick: (URL) -> Void
    
    var body: some View {
        let attributedString = createAttributedString(from: text)
        
        if let attributedString = attributedString {
            Text(attributedString)
                .font(.system(size: 16))
                .lineSpacing(4)
                .environment(\.openURL, OpenURLAction { url in
                    onURLClick(url)
                    return .handled
                })
                .textSelection(.enabled) // Enable text selection for easy copying
        } else {
            Text(text)
                .font(.system(size: 16))
                .foregroundStyle(PMColor.textSecondary)
                .lineSpacing(4)
                .textSelection(.enabled)
        }
    }
    
    private func createAttributedString(from text: String) -> AttributedString? {
        // Detect URLs (including mailto:), phone numbers
        let types: NSTextCheckingResult.CheckingType = [.link, .phoneNumber]
        guard let detector = try? NSDataDetector(types: types.rawValue) else {
            return nil
        }
        
        // Also detect emails using regex (NSDataDetector may miss some email formats)
        let emailPattern = #"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#
        let emailRegex = try? NSRegularExpression(pattern: emailPattern, options: [])
        
        let range = NSRange(location: 0, length: text.utf16.count)
        let matches = detector.matches(in: text, options: [], range: range)
        let emailMatches = emailRegex?.matches(in: text, options: [], range: range) ?? []
        
        guard !matches.isEmpty || !emailMatches.isEmpty else {
            return nil
        }
        
        var attributedString = AttributedString(text)
        attributedString.foregroundColor = PMColor.textSecondary
        
        // Track processed ranges to avoid duplicates
        var processedRanges: Set<Range<String.Index>> = []
        
        // Process NSDataDetector matches
        for match in matches {
            guard let matchRange = Range(match.range, in: text),
                  let attributedRange = Range(matchRange, in: attributedString) else {
                continue
            }
            
            processedRanges.insert(matchRange)
            var url: URL?
            
            // Handle different match types
            switch match.resultType {
            case .link:
                url = match.url
            case .phoneNumber:
                if let phoneNumber = match.phoneNumber {
                    // Clean phone number for tel: URL
                    let cleanPhone = phoneNumber.replacingOccurrences(of: " ", with: "")
                        .replacingOccurrences(of: "-", with: "")
                        .replacingOccurrences(of: "(", with: "")
                        .replacingOccurrences(of: ")", with: "")
                        .replacingOccurrences(of: ".", with: "")
                    url = URL(string: "tel:\(cleanPhone)")
                }
            default:
                break
            }
            
            // Style the detected text
            attributedString[attributedRange].foregroundColor = PMColor.coral
            attributedString[attributedRange].underlineStyle = .single
            
            // Make it clickable if we have a URL
            if let url = url {
                attributedString[attributedRange].link = url
            }
        }
        
        // Process email matches from regex (if not already handled)
        for emailMatch in emailMatches {
            guard let emailRange = Range(emailMatch.range, in: text),
                  !processedRanges.contains(emailRange),
                  let attributedRange = Range(emailRange, in: attributedString) else {
                continue
            }
            
            let emailString = String(text[emailRange])
            if let mailtoURL = URL(string: "mailto:\(emailString)") {
                attributedString[attributedRange].foregroundColor = PMColor.coral
                attributedString[attributedRange].underlineStyle = .single
                attributedString[attributedRange].link = mailtoURL
            }
        }
        
        return attributedString
    }
}

// MARK: - Status Badge

private struct StatusBadge: View {
    let label: String
    var isPositive: Bool = false
    var isUnknown: Bool = false
    
    var body: some View {
        HStack(spacing: 8) {
            if isUnknown {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PMColor.textTertiary)
            } else {
                Image(systemName: isPositive ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isPositive ? PMColor.success : PMColor.nopeText)
            }
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(PMColor.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            isUnknown 
                ? PMColor.textTertiary.opacity(0.1)
                : (isPositive ? PMColor.success.opacity(0.1) : PMColor.nopeText.opacity(0.1))
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

// MARK: - WrappingHStack for chips

struct WrappingHStack<Item: Identifiable & Hashable, Content: View>: View {
    let items: [Item]
    let spacing: CGFloat
    let content: (Item) -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            ForEach(createRows(), id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(row) { item in
                        content(item)
                    }
                    Spacer()
                }
            }
        }
    }
    
    private func createRows() -> [[Item]] {
        var rows: [[Item]] = []
        var currentRow: [Item] = []
        var currentRowWidth: CGFloat = 0
        let screenWidth = UIScreen.main.bounds.width - 40 // Account for padding
        
        for item in items {
            // Estimate width (approximate - chips are typically 60-120 points wide)
            let estimatedWidth: CGFloat = 100
            let itemWidth = estimatedWidth + spacing
            
            if currentRowWidth + itemWidth > screenWidth && !currentRow.isEmpty {
                rows.append(currentRow)
                currentRow = [item]
                currentRowWidth = itemWidth
            } else {
                currentRow.append(item)
                currentRowWidth += itemWidth
            }
        }
        
        if !currentRow.isEmpty {
            rows.append(currentRow)
        }
        
        return rows
    }
}

#if DEBUG
private struct PreviewPetRepository: PetRepository {
    let pets: [Pet]

    func loadInitialPets() async throws -> [Pet] { pets }
    func loadMorePetsIfAvailable() async throws -> [Pet] { [] }
    func loadPetDetails(petID: String) async throws -> Pet {
        pets.first(where: { $0.id == petID }) ?? pets.first!
    }
    func loadSearchForm(species: String) async throws -> PetSearchForm { PetSearchForm() }
}
#endif

