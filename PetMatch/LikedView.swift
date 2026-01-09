//
//  LikedView.swift
//  PetMatch
//

import SwiftUI

struct LikedView: View {
    @ObservedObject var viewModel: PetDeckViewModel
    @State private var selectedPet: Pet?
    @State private var safariURL: URL?
    @State private var visiblePets: Set<String> = []

    var body: some View {
        NavigationStack {
            ZStack {
                PMColor.background
                    .ignoresSafeArea()
                
                content
            }
            .sheet(item: $selectedPet) { pet in
                PetDetailView(
                    pet: pet,
                    repository: viewModel.repository
                )
                .presentationDetents([.large])
            }
            .sheet(isPresented: Binding(
                get: { safariURL != nil },
                set: { if !$0 { safariURL = nil } }
            )) {
                if let url = safariURL {
                    SafariView(url: url, tintColor: UIColor(PMColor.coral))
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.liked.isEmpty {
            emptyState
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ],
                    spacing: 20
                ) {
                    ForEach(Array(viewModel.liked.indices), id: \.self) { index in
                        let pet = viewModel.liked[index]
                        LikedPetCard(
                            pet: pet,
                            index: index,
                            isVisible: visiblePets.contains(pet.id)
                        ) {
                            selectedPet = pet
                        } onOpenLink: {
                            if let url = pet.detailsURL {
                                safariURL = url
                            }
                        } onRemove: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                viewModel.removeLike(pet)
                            }
                            Haptics.lightImpact()
                        }
                        .onAppear {
                            withAnimation(.easeOut(duration: 0.3).delay(Double(index) * 0.05)) {
                                _ = visiblePets.insert(pet.id)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [PMColor.coral.opacity(0.2), PMColor.mint.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: "heart.slash.fill")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [PMColor.coral, PMColor.coralSoft],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 10) {
                Text("No favorites yet")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(PMColor.textPrimary)
                Text("Swipe right on pets you love\nto save them here")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(PMColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct LikedPetCard: View {
    let pet: Pet
    let index: Int
    let isVisible: Bool
    let onTap: () -> Void
    let onOpenLink: () -> Void
    let onRemove: () -> Void
    
    @State private var isPressed = false
    @State private var imageLoaded = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Image Section
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: pet.thumbnail) { phase in
                    switch phase {
                    case .empty:
                        ZStack {
                            LinearGradient.primaryPetGradient
                            ProgressView()
                                .tint(.white)
                        }
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 180)
                            .clipped()
                            .onAppear {
                                withAnimation(.easeIn(duration: 0.3)) {
                                    imageLoaded = true
                                }
                            }
                    case .failure:
                        ZStack {
                            LinearGradient.supportGradient
                            Image(systemName: "pawprint.fill")
                                .font(.system(size: 40, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    @unknown default:
                        Color.gray.opacity(0.2)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .clipped()
                .overlay(
                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(0.3)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                
                // Remove button
                Button {
                    onRemove()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(.white)
                        .background(
                            Circle()
                                .fill(Color.black.opacity(0.3))
                                .blur(radius: 8)
                        )
                }
                .padding(12)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 180)
            .clipped()
            
            // Info Section
            VStack(alignment: .leading, spacing: 12) {
                Text(pet.name)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(PMColor.textPrimary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Action Buttons
                HStack(spacing: 10) {
                    Button {
                        onTap()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Details")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [PMColor.coral, PMColor.coralSoft],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    
                    if pet.detailsURL != nil {
                        Button {
                            onOpenLink()
                        } label: {
                            Text("🔗")
                                .font(.system(size: 20))
                                .frame(width: 44, height: 44)
                                .background(PMColor.coral.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 100)
            .background(PMColor.surface)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(
            color: Color.black.opacity(0.08),
            radius: 16,
            x: 0,
            y: 8
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.3),
                            Color.white.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .scaleEffect(isPressed ? 0.96 : (isVisible ? 1.0 : 0.9))
        .opacity(isVisible ? 1.0 : 0)
        .animation(
            .spring(response: 0.4, dampingFraction: 0.8),
            value: isPressed
        )
        .onTapGesture {
            onTap()
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    isPressed = true
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
}


#Preview {
    LikedView(viewModel: PetDeckViewModel(repository: PreviewPetRepository(pets: SamplePets.all)))
}

private struct PreviewPetRepository: PetRepository {
    let pets: [Pet]

    func loadInitialPets() async throws -> [Pet] { pets }
    func loadMorePetsIfAvailable() async throws -> [Pet] { [] }
    func loadPetDetails(petID: String) async throws -> Pet {
        pets.first(where: { $0.id == petID }) ?? pets.first!
    }
    func loadSearchForm(species: String) async throws -> PetSearchForm { PetSearchForm() }
}
