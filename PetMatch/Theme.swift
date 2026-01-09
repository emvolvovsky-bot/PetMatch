//
//  Theme.swift
//  PetMatch
//
//  Defines design tokens and helpers for the placeholder app.
//

import SwiftUI

enum PMColor {
    static let background = Color(hex: "#F7F7FB")
    static let surface = Color.white
    static let secondarySurface = Color(hex: "#F2F2F8")

    static let coral = Color(hex: "#FF6B6B")
    static let coralSoft = Color(hex: "#FF8FA3")
    static let mint = Color(hex: "#4ECDC4")
    static let mintSoft = Color(hex: "#5EEAD4")
    static let gold = Color(hex: "#F8D66D")

    static let success = Color(hex: "#22C55E")
    static let danger = Color(hex: "#EF4444")

    static let textPrimary = Color(hex: "#111827")
    static let textSecondary = Color(hex: "#4B5563")
    static let textTertiary = Color(hex: "#9CA3AF")
    static let divider = Color(hex: "#E5E7EB")

    static let likeBackground = Color(hex: "#DCFCE7")
    static let likeText = Color(hex: "#16A34A")
    static let nopeBackground = Color(hex: "#FEE2E2")
    static let nopeText = Color(hex: "#DC2626")
}

extension Color {
    init(hex: String) {
        let hex = hex.replacingOccurrences(of: "#", with: "")
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

extension LinearGradient {
    static let primaryPetGradient = LinearGradient(
        colors: [PMColor.coral, PMColor.coralSoft],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let supportGradient = LinearGradient(
        colors: [PMColor.mint, PMColor.mintSoft],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let dopamineNeon = LinearGradient(
        colors: [
            Color(hex: "#FF2BD6"), // neon pink
            Color(hex: "#7C3AED"), // electric purple
            Color(hex: "#22D3EE")  // aqua
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let dopamineWarm = LinearGradient(
        colors: [
            Color(hex: "#FF7A18"), // warm orange
            Color(hex: "#FBBF24"), // gold
            Color(hex: "#FF2BD6")  // neon accent
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let dopamineCalm = LinearGradient(
        colors: [
            Color(hex: "#0EA5E9"), // sky
            Color(hex: "#34D399"), // mint
            Color(hex: "#22D3EE")  // aqua
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Dopamine system visuals

enum DopamineGradientStyle {
    case neon
    case warm
    case calm
}

struct DopamineGradientBackground: View {
    var style: DopamineGradientStyle = .calm
    @State private var rotation: Double = 0

    private var colors: [Color] {
        switch style {
        case .neon:
            return [Color(hex: "#FF2BD6"), Color(hex: "#7C3AED"), Color(hex: "#22D3EE"), Color(hex: "#FF7A18")]
        case .warm:
            return [Color(hex: "#FF7A18"), Color(hex: "#FBBF24"), Color(hex: "#FF2BD6"), Color(hex: "#7C3AED")]
        case .calm:
            return [Color(hex: "#0EA5E9"), Color(hex: "#34D399"), Color(hex: "#22D3EE"), Color(hex: "#7C3AED")]
        }
    }

    var body: some View {
        ZStack {
            PMColor.background

            AngularGradient(colors: colors, center: .center)
                .rotationEffect(.degrees(rotation))
                .opacity(0.22)
                .blur(radius: 70)

            // A second layer adds that slow “premium motion” shimmer.
            AngularGradient(colors: colors.reversed(), center: .center)
                .rotationEffect(.degrees(-rotation * 0.85))
                .opacity(0.12)
                .blur(radius: 90)
        }
        .onAppear {
            withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

struct DopamineMoleculeWatermark: View {
    @State private var isVisible = false
    @State private var drift: CGSize = .zero

    var body: some View {
        Canvas { context, size in
            guard isVisible else { return }

            let base = CGPoint(x: size.width * 0.78 + drift.width, y: size.height * 0.22 + drift.height)
            let nodes: [CGPoint] = [
                base,
                CGPoint(x: base.x - 34, y: base.y + 26),
                CGPoint(x: base.x - 76, y: base.y + 10),
                CGPoint(x: base.x - 92, y: base.y - 32),
                CGPoint(x: base.x - 54, y: base.y - 62),
                CGPoint(x: base.x - 14, y: base.y - 36),
                CGPoint(x: base.x + 18, y: base.y - 6)
            ]

            var lines = Path()
            for (a, b) in [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 0), (0, 6)] {
                lines.move(to: nodes[a])
                lines.addLine(to: nodes[b])
            }

            context.stroke(
                lines,
                with: .linearGradient(
                    Gradient(colors: [Color.white.opacity(0.28), Color.white.opacity(0.08)]),
                    startPoint: nodes[3],
                    endPoint: nodes[0]
                ),
                lineWidth: 1.0
            )

            for (idx, p) in nodes.enumerated() {
                let r: CGFloat = idx == 0 ? 5.2 : 4.2
                let rect = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
                context.fill(Path(ellipseIn: rect), with: .color(Color.white.opacity(idx == 0 ? 0.22 : 0.12)))
            }
        }
        .opacity(isVisible ? 1 : 0)
        .animation(.easeInOut(duration: 0.6), value: isVisible)
        .task(id: "watermark-animation") {
            // Occasional, subtle appearance—never constant.
            // Use cancellable task to prevent resource leaks
            while !Task.isCancelled {
                let wait = UInt64(Double.random(in: 7...14) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: wait)
                
                // Check cancellation before continuing
                guard !Task.isCancelled else { break }
                
                drift = CGSize(width: CGFloat.random(in: -16...16), height: CGFloat.random(in: -12...12))
                isVisible = true
                
                let onTime = UInt64(Double.random(in: 2.5...4.2) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: onTime)
                
                // Check cancellation before hiding
                guard !Task.isCancelled else { break }
                isVisible = false
            }
        }
        .blendMode(.softLight)
        .allowsHitTesting(false)
    }
}

