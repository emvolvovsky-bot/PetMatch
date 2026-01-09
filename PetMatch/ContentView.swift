//
//  ContentView.swift
//  PetMatch
//
//  Created by Emil Volvovsky on 1/5/26.
//

import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var viewModel = PetDeckViewModel()
    @State private var showLaunchOverlay = true
    @State private var launchStart = Date()
    @State private var selectedTab: AppTab = .discover

    var body: some View {
        ZStack {
            DopamineGradientBackground()
                .ignoresSafeArea()

            Group {
                switch selectedTab {
                case .discover:
                    DiscoverView(viewModel: viewModel)
                case .map:
                    PetMapView(viewModel: viewModel)
                case .news:
                    NewsView()
                case .likes:
                    LikedView(viewModel: viewModel)
                }
            }
            .safeAreaInset(edge: .bottom) {
                CustomTabBar(selected: $selectedTab)
            }

            if showLaunchOverlay {
                LaunchLoadingOverlay()
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
                    .zIndex(10)
            }
        }
        .tint(PMColor.coral)
        .task {
            // Keep it feeling premium: show for a minimum duration, then fade out.
            launchStart = Date()
            let minDuration: TimeInterval = 1.0
            let elapsed = Date().timeIntervalSince(launchStart)
            if elapsed < minDuration {
                let remaining = UInt64((minDuration - elapsed) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: remaining)
            }
            withAnimation(.easeOut(duration: 0.35)) {
                showLaunchOverlay = false
            }
        }
    }
}

#Preview {
    ContentView()
}

// MARK: - Launch / Loading

private struct LaunchLoadingOverlay: View {
    @State private var isSpinning = false
    @State private var glowPulse = false

    var body: some View {
        ZStack {
            DopamineGradientBackground(style: .neon)
                .ignoresSafeArea()

            DopamineMoleculeWatermark()
                .ignoresSafeArea()
                .opacity(0.35)

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.14))
                        .frame(width: 260, height: 260)
                        .overlay(
                            Circle()
                                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
                        )
                        .shadow(color: PMColor.coral.opacity(glowPulse ? 0.32 : 0.18), radius: glowPulse ? 26 : 18, x: 0, y: 16)

                    PetCarrierIcon()
                        .frame(width: 400, height: 400)
                        .rotationEffect(.degrees(isSpinning ? 360 : 0))
                        .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: false), value: isSpinning)
                        .shadow(color: Color.black.opacity(0.22), radius: 18, x: 0, y: 16)
                }

                VStack(spacing: 6) {
                    Text("PetMatch")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.95))
                    Text("Finding your perfect match…")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            isSpinning = true
            withAnimation(.easeInOut(duration: 1.35).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
        }
    }
}

private struct PetCarrierIcon: View {
    var body: some View {
        // First image: gradient-filled carrier with heart cutout (spinning loading logo)
        // Add this PNG to Assets.xcassets as an image set named "LoadingLogo"
        if let uiImage = UIImage(named: "LoadingLogo") {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "shippingbox.fill")
                .resizable()
                .scaledToFit()
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white.opacity(0.92))
        }
    }
}
