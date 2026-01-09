//
//  PetCardView.swift
//  PetMatch
//

import SwiftUI

struct PetCardView: View {
    let pet: Pet
    let overlayLabel: SwipeDirection?
    let isTopCard: Bool
    var dragOffset: CGSize = .zero

    var body: some View {
        let tiltX = Double(dragOffset.height / 28) // pitch
        let tiltY = Double(-dragOffset.width / 22) // yaw
        let dragMagnitude = min(1, Double(abs(dragOffset.width) / 180))

        VStack(spacing: 0) {
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
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 6)
                        .background(PMColor.surface)
                case .failure:
                    ZStack {
                        LinearGradient.supportGradient
                        Image(systemName: "pawprint.fill")
                            .font(.system(size: 48, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                @unknown default:
                    Color.gray.opacity(0.2)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 360)
            .background(PMColor.surface) // fills any leftover frame area so the card is never transparent
            .overlay(alignment: .topLeading) {
                if let overlayLabel {
                    SwipeStamp(direction: overlayLabel)
                        .padding(20)
                        .transition(.scale.combined(with: .opacity))
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(pet.name)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(PMColor.textPrimary)
                    Spacer()
                    Text(pet.ageDisplay)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(PMColor.textSecondary)
                }

                Text(pet.breedDisplay)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(PMColor.textSecondary)

                Text(pet.locationDisplay)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(PMColor.textTertiary)

                HStack(spacing: 8) {
                    ForEach(pet.cardChips) { chip in
                        ChipView(text: chip.label, backgroundHex: chip.background, foregroundHex: chip.foreground)
                    }
                }
                .padding(.top, 4)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PMColor.surface)
        }
        .background(PMColor.surface) // ensures the entire card surface is opaque
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: Color.black.opacity(isTopCard ? 0.08 : 0.04), radius: isTopCard ? 18 : 12, x: 0, y: isTopCard ? 14 : 10)
        .overlay(
            RoundedRectangle(cornerRadius: 26)
                .fill(PMColor.secondarySurface.opacity(isTopCard ? 0 : 0.14))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26)
                .stroke(PMColor.secondarySurface, lineWidth: 1)
        )
        .overlay(
            // Soft “premium” border glow while dragging (subtle, not flashy).
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(LinearGradient.dopamineNeon.opacity(0.85), lineWidth: isTopCard ? (dragMagnitude > 0.05 ? 1.6 : 0) : 0)
                .opacity(isTopCard ? (0.10 + 0.24 * dragMagnitude) : 0)
                .blendMode(.plusLighter)
        )
        .rotation3DEffect(.degrees(isTopCard ? tiltX : 0), axis: (x: 1, y: 0, z: 0), perspective: 0.65)
        .rotation3DEffect(.degrees(isTopCard ? tiltY : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.65)
        .animation(.spring(response: 0.28, dampingFraction: 0.85), value: dragOffset)
    }
}

private struct SwipeStamp: View {
    let direction: SwipeDirection

    var body: some View {
        Text(direction == .like ? "LIKE" : "NOPE")
            .font(.system(size: 20, weight: .heavy))
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(direction == .like ? PMColor.likeBackground : PMColor.nopeBackground)
            .foregroundStyle(direction == .like ? PMColor.likeText : PMColor.nopeText)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .rotationEffect(.degrees(direction == .like ? -12 : 12))
            .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 8)
    }
}

struct ChipView: View {
    let text: String
    let backgroundHex: String
    let foregroundHex: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(hex: backgroundHex))
            .foregroundStyle(Color(hex: foregroundHex))
            .clipShape(Capsule(style: .continuous))
    }
}

#Preview {
    PetCardView(
        pet: SamplePets.all.first!,
        overlayLabel: .like
        , isTopCard: true
    )
    .padding()
    .background(PMColor.background)
}

