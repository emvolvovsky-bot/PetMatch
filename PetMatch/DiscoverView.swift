//
//  DiscoverView.swift
//  PetMatch
//

import SwiftUI
import CoreLocation

struct DiscoverView: View {
    @ObservedObject var viewModel: PetDeckViewModel
    @State private var selectedPet: Pet?
    @State private var showErrorAlert = false
    @State private var swipeRequest: SwipeRequest?
    @State private var dopamineBurstID = UUID()
    @State private var showFilters = false
    @State private var showLikeAnimation = false
    @State private var showNopeAnimation = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // Keep Discover consistent with the app's lighter palette.
                PMColor.background.ignoresSafeArea()

                // Dopamine burst overlay
                DopamineBurstOverlay(burstID: dopamineBurstID)
                    .allowsHitTesting(false)

                VStack(spacing: 18) {
                    header
                    cardStack
                    Spacer(minLength: 6)
                    bottomButtons
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.horizontal, 20)
                .padding(.top, 8)   // nudge header up slightly
                .padding(.bottom, 12)
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .sheet(item: $selectedPet) { pet in
                PetDetailView(
                    pet: pet,
                    repository: viewModel.repository,
                    primaryActionTitle: "Save to likes",
                    onPrimaryAction: {
                        viewModel.swipe(pet, direction: .like)
                        // Dismiss the details sheet immediately after saving.
                        selectedPet = nil
                    }
                )
                .presentationDetents([.large])
            }
            .onChange(of: viewModel.errorMessage) { _, newValue in
                showErrorAlert = newValue != nil
            }
            .alert("Couldn't load pets", isPresented: $showErrorAlert) {
                Button("Retry") { Task { await viewModel.reload() } }
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "Please try again.")
            }
            .sheet(isPresented: $showFilters) {
                FilterView(viewModel: viewModel)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Discover")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(PMColor.textPrimary)
            Spacer()
            HStack(spacing: 12) {
                Button {
                    Haptics.softTap()
                    showFilters = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(PMColor.textPrimary)
                        .padding(12)
                        .background(PMColor.secondarySurface)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                
                Button {
                    Haptics.softTap()
                    viewModel.shuffleDeck()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(PMColor.textPrimary)
                        .padding(12)
                        .background(PMColor.secondarySurface)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var cardStack: some View {
        ZStack {
            if viewModel.deck.isEmpty {
                if viewModel.hasNoPetsAvailable {
                    noPetsAvailableState
                } else {
                    emptyState
                }
            } else {
                ForEach(Array(viewModel.currentTopPets().enumerated()), id: \.element.id) { index, pet in
                    let isTop = index == 0
                    SwipeCardContainer(
                        pet: pet,
                        isTopCard: isTop,
                        stackIndex: index,
                        swipeRequest: swipeRequest,
                        onTap: {
                            selectedPet = pet
                            Haptics.softTap()
                        },
                        onSwipe: { direction in
                            viewModel.swipe(pet, direction: direction)
                            if direction == .like {
                                showLikeAnimation = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    showLikeAnimation = false
                                }
                            } else {
                                showNopeAnimation = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    showNopeAnimation = false
                                }
                            }
                        },
                        onSwipeStart: {
                            // Trigger dopamine burst immediately when swipe starts
                            dopamineBurstID = UUID()
                        }
                    )
                    .id("\(pet.id)-\(index)")
                    .zIndex(Double(viewModel.currentTopPets().count - index))
                }
            }
        }
        // Slightly smaller + higher so buttons sit above the tab bar cleanly.
        .frame(height: 470)
        .padding(.top, 16)
        .animation(.spring(response: 0.5, dampingFraction: 0.9), value: viewModel.deck)
        .onChange(of: viewModel.deck.count) { _, _ in
            // Reset swipeRequest when deck changes (card was swiped)
            if swipeRequest != nil {
                swipeRequest = nil
            }
        }
    }

    private var bottomButtons: some View {
        HStack(spacing: 54) {
            // Nope button
            VStack(spacing: 8) {
                Text("-1")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(PMColor.nopeText)
                    .opacity(showNopeAnimation ? 1 : 0)
                    .offset(y: showNopeAnimation ? -8 : 0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showNopeAnimation)
                
                Button {
                    guard let pet = viewModel.currentTopPets().first else { return }
                    Haptics.softTap()
                    dopamineBurstID = UUID()
                    showNopeAnimation = true
                    swipeRequest = SwipeRequest(petID: pet.id, direction: .nope)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showNopeAnimation = false
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(showNopeAnimation ? PMColor.nopeText : .white)
                            .frame(width: 66, height: 66)
                            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 8)
                        
                        Image(systemName: "xmark")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(showNopeAnimation ? .white : PMColor.nopeText)
                    }
                }
                .buttonStyle(.plain)
            }
            
            // Like button
            VStack(spacing: 8) {
                Text("+1")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(PMColor.success)
                    .opacity(showLikeAnimation ? 1 : 0)
                    .offset(y: showLikeAnimation ? -8 : 0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showLikeAnimation)
                
                Button {
                    guard let pet = viewModel.currentTopPets().first else { return }
                    Haptics.success()
                    dopamineBurstID = UUID()
                    showLikeAnimation = true
                    swipeRequest = SwipeRequest(petID: pet.id, direction: .like)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showLikeAnimation = false
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(showLikeAnimation ? PMColor.success : .white)
                            .frame(width: 66, height: 66)
                            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 8)
                        
                        Image(systemName: showLikeAnimation ? "checkmark" : "checkmark")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(showLikeAnimation ? .white : PMColor.success)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 2)
        .padding(.bottom, 6)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(PMColor.secondarySurface)
                    .frame(width: 80, height: 80)
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(PMColor.coral)
            }
            Text("You've seen everyone nearby")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(PMColor.textPrimary)
            Text("Refresh to keep browsing or revisit your liked pets.")
                .font(.system(size: 16))
                .foregroundStyle(PMColor.textSecondary)
            Button {
                viewModel.shuffleDeck()
                Haptics.softTap()
            } label: {
                Text("Refresh deck")
                    .font(.system(size: 16, weight: .semibold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(LinearGradient.primaryPetGradient)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(PMColor.surface)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 8)
        )
    }
    
    private var noPetsAvailableState: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(PMColor.secondarySurface)
                    .frame(width: 80, height: 80)
                Image(systemName: "map.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(PMColor.coral)
            }
            Text("No pets available in this area yet")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(PMColor.textPrimary)
            Text("Try adjusting your filters or check back later.")
                .font(.system(size: 16))
                .foregroundStyle(PMColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(PMColor.surface)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 8)
        )
    }
}

private struct SwipeCardContainer: View {
    let pet: Pet
    let isTopCard: Bool
    let stackIndex: Int
    let swipeRequest: SwipeRequest?
    let onTap: () -> Void
    let onSwipe: (SwipeDirection) -> Void
    let onSwipeStart: (() -> Void)?

    @State private var offset: CGSize = .zero
    @State private var dragDirection: SwipeDirection?
    @State private var isFlyingAway = false
    @State private var heartOpacity: Double = 0
    @State private var heartScale: CGFloat = 0.7
    @State private var flashOpacity: Double = 0
    @State private var flashColor: Color = .clear
    @State private var pawBurstID = UUID()
    @State private var dustBurstID = UUID()
    @State private var badgeOpacity: Double = 0
    @State private var badgeOffset: CGSize = .zero
    @State private var dissolveOpacity: Double = 1
    @State private var dissolveScale: CGFloat = 1
    @State private var shakeTrigger: Int = 0

    private let swipeThreshold: CGFloat = 110
    
    private func resetCardState() {
        offset = .zero
        dragDirection = nil
        isFlyingAway = false
        dissolveOpacity = 1
        dissolveScale = 1
        heartOpacity = 0
        heartScale = 0.7
        flashOpacity = 0
        badgeOpacity = 0
        badgeOffset = .zero
    }

    var body: some View {
        let card = ZStack {
            PetCardView(
                pet: pet,
                overlayLabel: isTopCard ? dragDirection : nil,
                isTopCard: isTopCard,
                dragOffset: offset
            )
            commitFlash
            heartPulse
            PawConfettiBurst(burstID: pawBurstID)
                .allowsHitTesting(false)
            CoolDustBurst(burstID: dustBurstID)
                .allowsHitTesting(false)
            savedBadge
        }
        .opacity(dissolveOpacity)
        .scaleEffect(dissolveScale)
        // Make the stack feel tangible: 1–2 cards clearly peek behind.
        .scaleEffect(isTopCard ? 1 : 0.96 - CGFloat(stackIndex) * 0.04)
        .offset(y: isTopCard ? 0 : CGFloat(stackIndex) * 26)
        .padding(.horizontal, isTopCard ? 0 : CGFloat(stackIndex) * 10)
        .opacity(isTopCard ? 1 : 0.96 - Double(stackIndex) * 0.05)
        .offset(x: offset.width, y: offset.height)
        .rotationEffect(.degrees(Double(offset.width / 20)))
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: offset)
        .onTapGesture { onTap() }
        .modifier(ShakeEffect(trigger: shakeTrigger))
        .onChange(of: swipeRequest?.id) { _, _ in
            guard isTopCard else { return }
            guard let swipeRequest, swipeRequest.petID == pet.id else { return }
            completeSwipe(swipeRequest.direction, translation: .zero)
        }

        if isTopCard {
            card
                .id("top-\(pet.id)")
                .allowsHitTesting(true)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            guard !isFlyingAway else { return }
                            offset = value.translation
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                if value.translation.width > 20 { dragDirection = .like }
                                else if value.translation.width < -20 { dragDirection = .nope }
                                else { dragDirection = nil }
                            }
                        }
                        .onEnded { value in
                            guard !isFlyingAway else { return }
                            handleDragEnd(value.translation)
                        }
                )
                .onChange(of: pet.id) { oldID, newID in
                    // Reset all state when the pet changes (card becomes top)
                    if oldID != newID {
                        resetCardState()
                    }
                }
                .onChange(of: stackIndex) { oldIndex, newIndex in
                    // Reset state when this card becomes the top card (index 0)
                    if newIndex == 0 && oldIndex != 0 {
                        resetCardState()
                    }
                }
                .onAppear {
                    // Reset state when card first appears as top card
                    resetCardState()
                }
        } else {
            card
                .id("stack-\(pet.id)-\(stackIndex)")
                .allowsHitTesting(false)
        }
    }

    private func handleDragEnd(_ translation: CGSize) {
        let horizontal = translation.width
        if horizontal > swipeThreshold {
            completeSwipe(.like, translation: translation)
        } else if horizontal < -swipeThreshold {
            completeSwipe(.nope, translation: translation)
        } else {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                offset = .zero
                dragDirection = nil
            }
            Haptics.softTap()
        }
    }

    private func completeSwipe(_ direction: SwipeDirection, translation: CGSize) {
        guard !isFlyingAway else { return }
        isFlyingAway = true
        let horizontalTarget: CGFloat = direction == .like ? 1200 : -1200
        // Trigger dopamine burst immediately when swipe starts
        onSwipeStart?()
        triggerDopamine(direction: direction)

        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
            offset = CGSize(width: horizontalTarget, height: translation.height / 2)
            dragDirection = direction
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            onSwipe(direction)
            // Reset all state immediately after swipe completes
            resetCardState()
        }
    }

    private var heartPulse: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: 54, weight: .bold))
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, PMColor.coral)
            .opacity(heartOpacity)
            .scaleEffect(heartScale)
            .shadow(color: PMColor.coral.opacity(0.25), radius: 18, x: 0, y: 10)
            .offset(x: 0, y: -46)
            .allowsHitTesting(false)
    }

    private var commitFlash: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(flashColor)
            .opacity(flashOpacity)
            .allowsHitTesting(false)
    }

    private var savedBadge: some View {
        Text("Saved")
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
            )
            .opacity(badgeOpacity)
            .offset(badgeOffset)
            .shadow(color: Color.black.opacity(0.10), radius: 12, x: 0, y: 10)
            .allowsHitTesting(false)
    }

    private func triggerDopamine(direction: SwipeDirection) {
        // Reset visuals
        heartOpacity = 0
        heartScale = 0.65
        badgeOpacity = 0
        badgeOffset = .zero
        dissolveOpacity = 1
        dissolveScale = 1

        flashOpacity = 0
        flashColor = direction == .like ? PMColor.likeBackground : PMColor.nopeBackground

        if direction == .like {
            Haptics.success()
            shakeTrigger += 1
            pawBurstID = UUID()

            withAnimation(.spring(response: 0.28, dampingFraction: 0.55)) {
                heartOpacity = 1
                heartScale = 1.12
                flashOpacity = 0.22
            }
            withAnimation(.easeOut(duration: 0.28).delay(0.16)) {
                heartScale = 1.0
            }
            withAnimation(.easeOut(duration: 0.42).delay(0.18)) {
                heartOpacity = 0
                flashOpacity = 0
            }

            // “Save badge” gliding toward the favorites area (subtle, not jarring).
            withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                badgeOpacity = 1
                badgeOffset = CGSize(width: 90, height: 160)
            }
            withAnimation(.easeOut(duration: 0.35).delay(0.25)) {
                badgeOpacity = 0
            }
        } else {
            Haptics.softTap()
            WhooshSynth.shared.play()
            dustBurstID = UUID()

            // Calm dissolve: fade + scale down slightly (no “punishment” snap).
            withAnimation(.easeOut(duration: 0.18)) {
                dissolveOpacity = 0.92
                dissolveScale = 0.985
                flashOpacity = 0.12
            }
            withAnimation(.easeOut(duration: 0.35).delay(0.12)) {
                dissolveOpacity = 0.78
                dissolveScale = 0.965
                flashOpacity = 0
            }
        }
    }
}

// MARK: - Reward UI

private struct RewardProgressBar: View {
    let progress: Double
    let pulse: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(PMColor.secondarySurface.opacity(0.9))
                Capsule(style: .continuous)
                    .fill(LinearGradient.dopamineNeon)
                    .frame(width: max(8, geo.size.width * progress))
                    .shadow(color: PMColor.coral.opacity(pulse ? 0.34 : 0.18), radius: pulse ? 14 : 10, x: 0, y: 10)
                    .animation(.spring(response: 0.35, dampingFraction: 0.72), value: progress)
            }
        }
    }
}

// MARK: - Micro-interactions

private struct ShakeEffect: GeometryEffect {
    var travelDistance: CGFloat = 7
    var shakesPerUnit = 2
    var animatableData: CGFloat

    init(trigger: Int) {
        animatableData = CGFloat(trigger)
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let translationX = travelDistance * sin(animatableData * .pi * CGFloat(shakesPerUnit))
        return ProjectionTransform(CGAffineTransform(translationX: translationX, y: 0))
    }
}

private struct PawConfettiBurst: View {
    let burstID: UUID
    @State private var particles: [Particle] = []

    var body: some View {
        ZStack {
            ForEach(particles) { p in
                Image(systemName: "pawprint.fill")
                    .font(.system(size: p.size, weight: .semibold))
                    .foregroundStyle(p.color)
                    .rotationEffect(.degrees(p.rotation))
                    .offset(p.offset)
                    .opacity(p.opacity)
                    .scaleEffect(p.scale)
                    .allowsHitTesting(false)
            }
        }
        .onChange(of: burstID) { _, _ in
            spawn()
        }
    }

    private func spawn() {
        particles = (0..<14).map { _ in
            let angle = Double.random(in: (-.pi / 2)...(.pi / 2))
            let distance = CGFloat.random(in: 70...140)
            return Particle(
                id: UUID(),
                offset: .zero,
                target: CGSize(width: cos(angle) * distance, height: -sin(angle) * distance - CGFloat.random(in: 10...40)),
                size: CGFloat.random(in: 10...14),
                rotation: Double.random(in: -25...25),
                scale: 0.85,
                opacity: 0,
                color: [PMColor.coral, PMColor.gold, PMColor.mint].randomElement()!.opacity(0.92)
            )
        }

        // Pop in quickly (~0.2s), then vanish.
        withAnimation(.easeOut(duration: 0.12)) {
            particles = particles.map { p in
                var p = p
                p.opacity = 1
                p.scale = 1
                return p
            }
        }
        withAnimation(.easeOut(duration: 0.20)) {
            particles = particles.map { p in
                var p = p
                p.offset = p.target
                p.opacity = 0
                p.scale = 0.9
                return p
            }
        }
    }

    private struct Particle: Identifiable {
        let id: UUID
        var offset: CGSize
        let target: CGSize
        let size: CGFloat
        let rotation: Double
        var scale: CGFloat
        var opacity: Double
        let color: Color
    }
}

private struct CoolDustBurst: View {
    let burstID: UUID
    @State private var dots: [Dot] = []

    var body: some View {
        Canvas { context, _ in
            for d in dots {
                var path = Path()
                path.addEllipse(in: CGRect(x: d.x, y: d.y, width: d.r * 2, height: d.r * 2))
                context.fill(path, with: .color(d.color.opacity(d.opacity)))
            }
        }
        .onChange(of: burstID) { _, _ in
            spawn()
        }
        .allowsHitTesting(false)
    }

    private func spawn() {
        dots = (0..<22).map { _ in
            Dot(
                id: UUID(),
                x: Double.random(in: -40...40),
                y: Double.random(in: -20...30),
                r: Double.random(in: 2.0...4.8),
                opacity: 0.0,
                color: [PMColor.mint.opacity(0.9), Color(hex: "#93C5FD").opacity(0.9)].randomElement()!
            )
        }
        withAnimation(.easeOut(duration: 0.10)) {
            dots = dots.map { d in
                var d = d
                d.opacity = 0.85
                return d
            }
        }
        withAnimation(.easeOut(duration: 0.32)) {
            dots = dots.map { d in
                var d = d
                d.x -= Double.random(in: 70...120)
                d.y += Double.random(in: 10...40)
                d.opacity = 0.0
                return d
            }
        }
    }

    private struct Dot: Identifiable {
        let id: UUID
        var x: Double
        var y: Double
        let r: Double
        var opacity: Double
        let color: Color
    }
}

private struct SwipeRequest: Equatable {
    let id = UUID()
    let petID: String
    let direction: SwipeDirection
}

// MARK: - Dopamine Burst Overlay

private struct DopamineBurstOverlay: View {
    let burstID: UUID
    @State private var isVisible = false
    @State private var scale: CGFloat = 0.3
    @State private var opacity: Double = 0
    
    var body: some View {
        ZStack {
            // Quick gradient burst flash - subtle neon pink/purple radial
            RadialGradient(
                colors: [
                    Color(hex: "#FF2BD6").opacity(0.4),
                    Color(hex: "#7C3AED").opacity(0.25),
                    Color.clear
                ],
                center: .center,
                startRadius: 30,
                endRadius: 200
            )
            .opacity(opacity)
            .scaleEffect(scale)
            .blur(radius: 20)
            
            // Subtle molecule watermark flash
            DopamineMoleculeWatermark()
                .opacity(isVisible ? 0.35 : 0)
                .scaleEffect(isVisible ? 1.15 : 0.85)
        }
        .allowsHitTesting(false)
        .onChange(of: burstID) { _, _ in
            triggerBurst()
        }
    }
    
    private func triggerBurst() {
        isVisible = false
        scale = 0.3
        opacity = 0
        
        withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
            isVisible = true
            scale = 1.0
            opacity = 0.32
        }
        
        withAnimation(.easeOut(duration: 0.35).delay(0.15)) {
            scale = 1.5
            opacity = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isVisible = false
        }
    }
}

// MARK: - Filter View

private struct FilterView: View {
    @ObservedObject var viewModel: PetDeckViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var filters: PetFilters
    @State private var showBreedSelection = false
    @State private var showLocationPicker = false
    @State private var tempLocationCoordinate: CLLocationCoordinate2D?
    @State private var tempRadiusMiles: Double = 25.0
    
    init(viewModel: PetDeckViewModel) {
        self.viewModel = viewModel
        _filters = State(initialValue: viewModel.filters)
        // Initialize temp values from existing filters
        if let lat = viewModel.filters.locationLatitude,
           let lon = viewModel.filters.locationLongitude {
            _tempLocationCoordinate = State(initialValue: CLLocationCoordinate2D(latitude: lat, longitude: lon))
        }
        if let radius = viewModel.filters.locationRadiusMiles {
            _tempRadiusMiles = State(initialValue: radius)
        }
    }
    
    private let allAges = ["puppy", "young", "adult", "senior"]
    private let allSizes = ["s", "m", "l", "xl"]
    private let allGenders = ["m", "f"]
    private let allColors = ["Black", "White", "Brown", "Gray", "Golden", "Orange", "Tabby", "Tricolor", "Brindle", "Cream"]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Map / Location
                    FilterSection(title: "Map / Location") {
                        Button {
                            showLocationPicker = true
                            Haptics.softTap()
                        } label: {
                            HStack {
                                if filters.hasLocationFilter {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "mappin.circle.fill")
                                                .font(.system(size: 16))
                                                .foregroundStyle(PMColor.coral)
                                            Text("Location set")
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundStyle(PMColor.textPrimary)
                                        }
                                        if let radius = filters.locationRadiusMiles {
                                            Text("\(Int(radius)) mile radius")
                                                .font(.system(size: 13))
                                                .foregroundStyle(PMColor.textSecondary)
                                        }
                                    }
                                } else {
                                    HStack {
                                        Image(systemName: "map")
                                            .font(.system(size: 16))
                                            .foregroundStyle(PMColor.textSecondary)
                                        Text("Set location & radius")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundStyle(PMColor.textSecondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(PMColor.textTertiary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(PMColor.secondarySurface)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        
                        if filters.hasLocationFilter {
                            Button {
                                clearLocationFilter()
                                Haptics.softTap()
                            } label: {
                                HStack {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 16))
                                    Text("Clear location filter")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .foregroundStyle(PMColor.nopeText)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(PMColor.nopeBackground.opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 8)
                        }
                    }
                    
                    // Species
                    FilterSection(title: "Species") {
                        HStack(spacing: 12) {
                            SpeciesToggle(
                                label: "Dogs",
                                icon: "🐶",
                                isSelected: filters.species.contains("dog")
                            ) {
                                toggleSpecies("dog")
                            }
                            
                            SpeciesToggle(
                                label: "Cats",
                                icon: "🐱",
                                isSelected: filters.species.contains("cat")
                            ) {
                                toggleSpecies("cat")
                            }
                        }
                    }
                    
                    // Breeds
                    FilterSection(title: "Breeds") {
                        Button {
                            showBreedSelection = true
                            Haptics.softTap()
                        } label: {
                            HStack {
                                Text(filters.breeds.isEmpty ? "Select breeds..." : "\(filters.breeds.count) breed\(filters.breeds.count == 1 ? "" : "s") selected")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(filters.breeds.isEmpty ? PMColor.textSecondary : PMColor.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(PMColor.textTertiary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(PMColor.secondarySurface)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Compatibility
                    FilterSection(title: "Compatibility") {
                        VStack(spacing: 12) {
                            CompatibilityToggle(
                                label: "Good with kids",
                                isSelected: filters.goodWithKids == true,
                                isUnknown: filters.goodWithKids == nil
                            ) {
                                toggleCompatibility(key: \.goodWithKids)
                            }
                            
                            CompatibilityToggle(
                                label: "Good with dogs",
                                isSelected: filters.dogsCompatible == true,
                                isUnknown: filters.dogsCompatible == nil
                            ) {
                                toggleCompatibility(key: \.dogsCompatible)
                            }
                            
                            CompatibilityToggle(
                                label: "Good with cats",
                                isSelected: filters.catsCompatible == true,
                                isUnknown: filters.catsCompatible == nil
                            ) {
                                toggleCompatibility(key: \.catsCompatible)
                            }
                        }
                    }
                    
                    // Age
                    FilterSection(title: "Age") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(allAges, id: \.self) { age in
                                    FilterChip(
                                        text: age.capitalized,
                                        isSelected: filters.ages.contains(age)
                                    ) {
                                        toggleAge(age)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Size
                    FilterSection(title: "Size") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(allSizes, id: \.self) { size in
                                    FilterChip(
                                        text: sizeLabel(size),
                                        isSelected: filters.sizes.contains(size)
                                    ) {
                                        toggleSize(size)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Gender
                    FilterSection(title: "Gender") {
                        HStack(spacing: 10) {
                            ForEach(allGenders, id: \.self) { gender in
                                FilterChip(
                                    text: gender == "m" ? "Male" : "Female",
                                    isSelected: filters.genders.contains(gender)
                                ) {
                                    toggleGender(gender)
                                }
                            }
                        }
                    }
                    
                    // Vaccinated
                    FilterSection(title: "Vaccinated") {
                        HStack(spacing: 12) {
                            VaccinatedToggle(
                                label: "Vaccinated",
                                state: filters.vaccinated == true ? .yes : (filters.vaccinated == false ? .no : .any)
                            ) {
                                toggleVaccinated()
                            }
                        }
                    }
                    
                    // Color
                    FilterSection(title: "Color") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(allColors, id: \.self) { color in
                                    FilterChip(
                                        text: color,
                                        isSelected: filters.colors.contains(color)
                                    ) {
                                        toggleColor(color)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(PMColor.background)
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") {
                        resetFilters()
                        Haptics.softTap()
                    }
                    .foregroundStyle(PMColor.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        applyFilters()
                        Haptics.softTap()
                        dismiss()
                    }
                    .foregroundStyle(PMColor.coral)
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showBreedSelection) {
                BreedSelectionView(
                    breeds: viewModel.availableBreeds,
                    selectedBreeds: $filters.breeds
                )
                .presentationDetents([.large])
            }
            .sheet(isPresented: $showLocationPicker) {
                MapLocationPickerView(
                    selectedCoordinate: $tempLocationCoordinate,
                    radiusMiles: $tempRadiusMiles
                )
                .onDisappear {
                    // Apply location filter when picker closes
                    if let coord = tempLocationCoordinate {
                        filters.locationLatitude = coord.latitude
                        filters.locationLongitude = coord.longitude
                        filters.locationRadiusMiles = tempRadiusMiles
                    }
                }
            }
        }
    }
    
    private func clearLocationFilter() {
        filters.locationLatitude = nil
        filters.locationLongitude = nil
        filters.locationRadiusMiles = nil
        tempLocationCoordinate = nil
    }
    
    private func toggleSpecies(_ species: String) {
        if filters.species.contains(species) {
            filters.species.remove(species)
        } else {
            filters.species.insert(species)
        }
        Haptics.softTap()
    }
    
    private func toggleCompatibility(key: WritableKeyPath<PetFilters, Bool?>) {
        let current = filters[keyPath: key]
        if current == true {
            filters[keyPath: key] = false
        } else if current == false {
            filters[keyPath: key] = nil
        } else {
            filters[keyPath: key] = true
        }
        Haptics.softTap()
    }
    
    private func toggleAge(_ age: String) {
        if filters.ages.contains(age) {
            filters.ages.remove(age)
        } else {
            filters.ages.insert(age)
        }
        Haptics.softTap()
    }
    
    private func toggleSize(_ size: String) {
        if filters.sizes.contains(size) {
            filters.sizes.remove(size)
        } else {
            filters.sizes.insert(size)
        }
        Haptics.softTap()
    }
    
    private func toggleGender(_ gender: String) {
        if filters.genders.contains(gender) {
            filters.genders.remove(gender)
        } else {
            filters.genders.insert(gender)
        }
        Haptics.softTap()
    }
    
    private func toggleVaccinated() {
        if filters.vaccinated == true {
            filters.vaccinated = false
        } else if filters.vaccinated == false {
            filters.vaccinated = nil
        } else {
            filters.vaccinated = true
        }
        Haptics.softTap()
    }
    
    private func toggleColor(_ color: String) {
        if filters.colors.contains(color) {
            filters.colors.remove(color)
        } else {
            filters.colors.insert(color)
        }
        Haptics.softTap()
    }
    
    private func sizeLabel(_ size: String) -> String {
        switch size {
        case "s": return "Small"
        case "m": return "Medium"
        case "l": return "Large"
        case "xl": return "Extra Large"
        default: return size.capitalized
        }
    }
    
    private func resetFilters() {
        filters = PetFilters()
    }
    
    private func applyFilters() {
        viewModel.filters = filters
    }
}

private struct FilterSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(PMColor.textPrimary)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SpeciesToggle: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(icon)
                    .font(.system(size: 20))
                Text(label)
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundStyle(isSelected ? .white : PMColor.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background {
                if isSelected {
                    LinearGradient.primaryPetGradient
                } else {
                    PMColor.secondarySurface
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct FilterChip: View {
    let text: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isSelected ? .white : PMColor.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background {
                    if isSelected {
                        LinearGradient.primaryPetGradient
                    } else {
                        PMColor.secondarySurface
                    }
                }
                .clipShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct CompatibilityToggle: View {
    let label: String
    let isSelected: Bool
    let isUnknown: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(PMColor.textPrimary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(PMColor.success)
                } else if !isUnknown {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(PMColor.nopeText)
                } else {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 20))
                        .foregroundStyle(PMColor.textTertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(PMColor.secondarySurface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private enum VaccinatedState {
    case yes, no, any
}

private struct VaccinatedToggle: View {
    let label: String
    let state: VaccinatedState
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(PMColor.textPrimary)
                Spacer()
                switch state {
                case .yes:
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(PMColor.success)
                case .no:
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(PMColor.nopeText)
                case .any:
                    Text("Any")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(PMColor.textTertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(PMColor.secondarySurface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Breed Selection View

private struct BreedSelectionView: View {
    let breeds: [String]
    @Binding var selectedBreeds: Set<String>
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    var filteredBreeds: [String] {
        if searchText.isEmpty {
            return breeds
        }
        return breeds.filter { breed in
            breed.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(PMColor.textTertiary)
                    TextField("Search breeds...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(PMColor.secondarySurface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)
                
                // Breeds list
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredBreeds, id: \.self) { breed in
                            BreedRow(
                                breed: breed,
                                isSelected: selectedBreeds.contains(breed)
                            ) {
                                toggleBreed(breed)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
            }
            .background(PMColor.background)
            .navigationTitle("Select Breeds")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear All") {
                        selectedBreeds.removeAll()
                        Haptics.softTap()
                    }
                    .foregroundStyle(PMColor.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        Haptics.softTap()
                        dismiss()
                    }
                    .foregroundStyle(PMColor.coral)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func toggleBreed(_ breed: String) {
        if selectedBreeds.contains(breed) {
            selectedBreeds.remove(breed)
        } else {
            selectedBreeds.insert(breed)
        }
        Haptics.softTap()
    }
}

private struct BreedRow: View {
    let breed: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(breed)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(PMColor.textPrimary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(PMColor.coral)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(isSelected ? PMColor.secondarySurface : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

