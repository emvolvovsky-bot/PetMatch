//
//  CustomTabBar.swift
//  PetMatch
//
//  Created by Emil Volvovsky on 1/5/26.
//

import SwiftUI

enum AppTab: String, CaseIterable {
    case discover
    case map
    case news
    case likes
    
    var icon: String {
        switch self {
        case .discover: return "pawprint.fill"
        case .map: return "map.fill"
        case .news: return "newspaper.fill"
        case .likes: return "heart.fill"
        }
    }
    
    var label: String {
        switch self {
        case .discover: return "Discover"
        case .map: return "Map"
        case .news: return "News"
        case .likes: return "Likes"
        }
    }
}

struct CustomTabBar: View {
    @Binding var selected: AppTab
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                TabButton(tab: tab, selected: $selected)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            Capsule()
                .fill(Material.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.12), radius: 24, x: 0, y: 10)
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 6)
    }
}

private struct TabButton: View {
    let tab: AppTab
    @Binding var selected: AppTab
    @State private var isPressed = false
    
    private var isSelected: Bool {
        selected == tab
    }
    
    var body: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                selected = tab
            }
            Haptics.softTap()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: isSelected ? 22 : 20, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? PMColor.coral : PMColor.textSecondary.opacity(0.5))
                    .scaleEffect(isSelected ? 1.08 : 1.0)
                    .offset(y: isSelected ? -1.5 : 0)
                
                Text(tab.label)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? PMColor.coral : PMColor.textSecondary.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .overlay(alignment: .bottom) {
                if isSelected {
                    Capsule()
                        .fill(PMColor.coral.opacity(0.35))
                        .frame(width: 28, height: 2.5)
                        .padding(.bottom, 1)
                        .transition(.opacity.combined(with: .scale(scale: 0.85)))
                }
            }
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .opacity(isPressed ? 0.75 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        withAnimation(.easeOut(duration: 0.1)) {
                            isPressed = true
                        }
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeOut(duration: 0.15)) {
                        isPressed = false
                    }
                }
        )
    }
}

