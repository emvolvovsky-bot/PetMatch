//
//  ActionButton.swift
//  PetMatch
//

import SwiftUI

struct ActionButton: View {
    let iconName: String
    let background: Color
    let iconColor: Color
    var size: CGFloat = 62
    var action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                isPressed = false
            }
            action()
        } label: {
            Image(systemName: iconName)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: size, height: size)
                .background(background)
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 8)
                .scaleEffect(isPressed ? 0.92 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HStack(spacing: 20) {
        ActionButton(iconName: "xmark", background: PMColor.secondarySurface, iconColor: PMColor.nopeText) {}
        ActionButton(iconName: "heart.fill", background: PMColor.coral, iconColor: .white) {}
    }
    .padding()
    .background(PMColor.background)
}











