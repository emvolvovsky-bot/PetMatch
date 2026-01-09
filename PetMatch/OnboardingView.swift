//
//  OnboardingView.swift
//  PetMatch
//
//  Onboarding flow that appears on first launch
//

import SwiftUI

struct OnboardingView: View {
    @Binding var hasSeenOnboarding: Bool
    @State private var currentPage = 0
    
    private let pages: [OnboardingPage] = [
        OnboardingPage(
            headline: "Welcome to PetMatch",
            copy: "Discover your perfect furry companion with a swipe.\nFind dogs and cats ready for their forever home.",
            iconName: "pawprint.fill"
        ),
        OnboardingPage(
            headline: "Swipe & Match",
            copy: "Browse through pets, swipe right to like,\nand save your favorites to connect later.",
            iconName: "heart.fill"
        ),
        OnboardingPage(
            headline: "Find Your Match",
            copy: "View detailed profiles, learn about each pet,\nand connect directly with adoption centers.",
            iconName: "magnifyingglass"
        ),
        OnboardingPage(
            headline: "Ready to Start?",
            copy: "Let's find your perfect pet companion!\nYour journey begins now.",
            iconName: "sparkles"
        )
    ]
    
    var body: some View {
        ZStack {
            DopamineGradientBackground(style: .neon)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Skip button - much more visible
                HStack {
                    Spacer()
                    Button {
                        skipOnboarding()
                    } label: {
                        Text("Skip")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                GlassCard(blurRadius: 20, opacity: 0.4)
                            )
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .strokeBorder(.white.opacity(0.3), lineWidth: 1.5)
                            )
                    }
                }
                .padding(.top, 20)
                .padding(.trailing, 24)
                
                Spacer()
                
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        OnboardingPageView(page: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // Custom page indicator
                HStack(spacing: 10) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? .white.opacity(0.9) : .white.opacity(0.3))
                            .frame(width: index == currentPage ? 10 : 8, height: index == currentPage ? 10 : 8)
                            .scaleEffect(index == currentPage ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(
                    GlassCard(blurRadius: 20, opacity: 0.2)
                )
                .cornerRadius(20)
                
                Spacer()
                
                // Navigation button
                HStack {
                    if currentPage > 0 {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                currentPage -= 1
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Back")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(
                                GlassCard(blurRadius: 20, opacity: 0.3)
                            )
                            .cornerRadius(16)
                        }
                        .transition(.opacity.combined(with: .scale))
                    }
                    
                    Spacer()
                    
                    Button {
                        if currentPage < pages.count - 1 {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                currentPage += 1
                            }
                        } else {
                            completeOnboarding()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                                .font(.system(size: 16, weight: .semibold))
                            if currentPage < pages.count - 1 {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [PMColor.coral, PMColor.coralSoft],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: PMColor.coral.opacity(0.4), radius: 20, x: 0, y: 10)
                    }
                    .transition(.opacity.combined(with: .scale))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 50)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentPage)
    }
    
    private func skipOnboarding() {
        withAnimation(.easeOut(duration: 0.4)) {
            hasSeenOnboarding = true
        }
    }
    
    private func completeOnboarding() {
        withAnimation(.easeOut(duration: 0.4)) {
            hasSeenOnboarding = true
        }
    }
}

// MARK: - Onboarding Page Model

struct OnboardingPage {
    let headline: String
    let copy: String
    let iconName: String
}

// MARK: - Onboarding Page View

struct OnboardingPageView: View {
    let page: OnboardingPage
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0
    
    // Determine if this is the first page (for larger logo)
    private var isFirstPage: Bool {
        page.headline == "Welcome to PetMatch"
    }
    
    var body: some View {
        GeometryReader { geometry in
            let screenHeight = geometry.size.height
            let isSmallScreen = screenHeight < 700
            let isVerySmallScreen = screenHeight < 650
            
            // Dynamic sizing based on screen height
            let logoSize: CGFloat = isFirstPage 
                ? (isSmallScreen ? 180 : 220)
                : (isSmallScreen ? 140 : 160)
            let logoGlowSize: CGFloat = isFirstPage
                ? (isSmallScreen ? 240 : 280)
                : (isSmallScreen ? 180 : 200)
            let headlineSize: CGFloat = isVerySmallScreen ? 28 : (isSmallScreen ? 32 : 36)
            let copySize: CGFloat = isVerySmallScreen ? 16 : (isSmallScreen ? 17 : 19)
            let logoPadding: CGFloat = isSmallScreen ? 20 : 32
            let textSpacing: CGFloat = isSmallScreen ? 14 : 18
            
            VStack(spacing: 0) {
                Spacer()
                
                // App Logo - responsive sizing
                HStack {
                    Spacer()
                    ZStack {
                        // Glowing background circle
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        PMColor.coral.opacity(0.2),
                                        PMColor.coral.opacity(0.0)
                                    ],
                                    center: .center,
                                    startRadius: isFirstPage ? 40.0 : 25.0,
                                    endRadius: isFirstPage ? (isSmallScreen ? 110.0 : 140.0) : 100.0
                                )
                            )
                            .frame(width: logoGlowSize, height: logoGlowSize)
                            .blur(radius: 20)
                        
                        // Glass card container for logo
                        ZStack {
                            GlassCard(blurRadius: 30, opacity: 0.25)
                                .frame(width: logoSize, height: logoSize)
                                .cornerRadius(logoSize * 0.22)
                                .overlay(
                                    RoundedRectangle(cornerRadius: logoSize * 0.22)
                                        .strokeBorder(
                                            LinearGradient(
                                                colors: [
                                                    .white.opacity(0.3),
                                                    .white.opacity(0.1)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1.5
                                        )
                                )
                            
                            // Logo or icon
                            if let uiImage = UIImage(named: "LoadingLogo") {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: logoSize * 0.68, height: logoSize * 0.68)
                            } else {
                                Image(systemName: page.iconName)
                                    .font(.system(size: logoSize * 0.36, weight: .light))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.white.opacity(0.95), .white.opacity(0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                        }
                    }
                    Spacer()
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
                .padding(.top, isSmallScreen ? 10 : 20)
                .padding(.bottom, isSmallScreen ? 20 : logoPadding)
                .onAppear {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
                        logoScale = 1.0
                        logoOpacity = 1.0
                    }
                }
                
                // Text content - responsive and striking
                HStack {
                    Spacer()
                    VStack(spacing: textSpacing) {
                        Text(page.headline)
                            .font(.system(size: headlineSize, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.8)
                            .lineLimit(3)
                            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                            .shadow(color: .white.opacity(0.2), radius: 2, x: 0, y: 1)
                        
                        Text(page.copy)
                            .font(.system(size: copySize, weight: .semibold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .minimumScaleFactor(0.85)
                            .lineLimit(4)
                            .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, isSmallScreen ? 24 : 32)
                    .padding(.vertical, isSmallScreen ? 24 : 32)
                    .background(
                        GlassCard(blurRadius: 40, opacity: 0.35)
                    )
                    .cornerRadius(28)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.4),
                                        .white.opacity(0.15)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
                    .padding(.horizontal, 24)
                    .opacity(logoOpacity)
                    Spacer()
                }
                .padding(.bottom, isSmallScreen ? 10 : 20)
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Glass Card Component

struct GlassCard: View {
    let blurRadius: CGFloat
    let opacity: Double
    
    var body: some View {
        ZStack {
            // Base blur effect
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(opacity)
            
            // Gradient overlay for depth
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.15),
                            .white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .background(
            // Blur background
            Rectangle()
                .fill(.white.opacity(0.1))
                .blur(radius: blurRadius)
        )
    }
}

#Preview {
    OnboardingView(hasSeenOnboarding: .constant(false))
}

