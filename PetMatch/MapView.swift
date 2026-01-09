//
//  MapView.swift
//  PetMatch
//
//  Full-screen map view showing liked pets as pins with clustering and viewport filtering
//

import SwiftUI
import MapKit

struct PetMapView: View {
    @ObservedObject var viewModel: PetDeckViewModel
    @StateObject private var locationManager = LocationManager()
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 2.0, longitudeDelta: 2.0)
    )
    @State private var selectedPet: Pet?
    @State private var selectedCluster: PetCluster?
    @State private var isLoadingCoordinates = false
    @State private var visiblePets: [Pet] = []
    @State private var debounceTask: Task<Void, Never>?
    @State private var lastRegionCenter: CLLocationCoordinate2D?
    @State private var lastRegionSpan: MKCoordinateSpan?
    
    // Clustering thresholds based on zoom level (latitudeDelta)
    private let maxClusteringZoom: Double = 0.5 // Above this delta, cluster (zoomed out)
    private let minIndividualZoom: Double = 0.05 // Below this delta, show all individuals (zoomed in)
    private let clusterRadiusMeters: Double = 20000 // Max distance for clustering (20km at max zoom)
    
    // Debounce delay for viewport updates
    private let debounceDelay: TimeInterval = 0.3
    
    var body: some View {
        NavigationStack {
            ZStack {
                mapView
                previewCardOverlay
            }
            .navigationTitle("Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    locationButton
                }
            }
            .onAppear {
                loadPetCoordinates()
                if let currentLoc = locationManager.currentLocation {
                    region.center = currentLoc.coordinate
                }
                updateVisiblePets()            }
            .onChange(of: locationManager.currentLocation) { _, newLocation in
                if let location = newLocation {
                    withAnimation {
                        region.center = location.coordinate
                    }
                }
            }
            .onChange(of: viewModel.liked) { _, _ in
                updateVisiblePets()
                // Reload coordinates when liked pets change
                loadPetCoordinates()
            }
        }
        .sheet(item: $selectedPet) { pet in
            petDetailSheet(pet: pet)
        }
        .sheet(item: $selectedCluster) { cluster in
            clusterDetailSheet(cluster: cluster)
        }
    }
    
    // MARK: - View Components
    
    private var mapView: some View {
        Map(coordinateRegion: $region, annotationItems: annotations) { annotation in
            MapAnnotation(coordinate: annotation.coordinate) {
                annotationView(for: annotation)
            }
        }
        .ignoresSafeArea()
        .onChange(of: region.center.latitude) { _, _ in
            checkRegionChanged()
        }
        .onChange(of: region.center.longitude) { _, _ in
            checkRegionChanged()
        }
        .onChange(of: region.span.latitudeDelta) { _, _ in
            checkRegionChanged()
        }
        .onChange(of: region.span.longitudeDelta) { _, _ in
            checkRegionChanged()
        }
    }
    
    private func checkRegionChanged() {
        let centerChanged = lastRegionCenter == nil || 
            abs(lastRegionCenter!.latitude - region.center.latitude) > 0.001 ||
            abs(lastRegionCenter!.longitude - region.center.longitude) > 0.001
        
        let spanChanged = lastRegionSpan == nil ||
            abs(lastRegionSpan!.latitudeDelta - region.span.latitudeDelta) > 0.01 ||
            abs(lastRegionSpan!.longitudeDelta - region.span.longitudeDelta) > 0.01
        
        if centerChanged || spanChanged {
            lastRegionCenter = region.center
            lastRegionSpan = region.span
            debouncedUpdateVisiblePets()
        }
    }
    
    @ViewBuilder
    private var previewCardOverlay: some View {
        if let pet = selectedPet {
            VStack {
                Spacer()
                PetMapPreviewCard(
                    pet: pet,
                    distance: distanceForPet(pet),
                    onTap: {},
                    onViewDetails: {}
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
    
    private var locationButton: some View {
        Button {
            locationManager.requestCurrentLocation()
        } label: {
            Image(systemName: "location.fill")
                .foregroundStyle(PMColor.coral)
        }
    }
    
    private func petDetailSheet(pet: Pet) -> some View {
            PetDetailView(
                pet: pet,
                repository: viewModel.repository,
                primaryActionTitle: "Save to likes",
                onPrimaryAction: {
                    viewModel.swipe(pet, direction: .like)
                    selectedPet = nil
                }
            )
            .presentationDetents([.large])
        }
    
    private func clusterDetailSheet(cluster: PetCluster) -> some View {
        ClusterDetailView(cluster: cluster) { pet in
            selectedCluster = nil
            selectedPet = pet
        }
    }
    
    // MARK: - View Rendering
    
    /// Create the appropriate view for a map annotation (cluster or pet pin)
    @ViewBuilder
    private func annotationView(for annotation: MapAnnotationItem) -> some View {
        if let cluster = annotation.cluster {
            ClusterPin(cluster: cluster)
                .onTapGesture {
                    selectedCluster = cluster
                    Haptics.softTap()
                }
        } else if let pet = annotation.pet {
            PetMapPin(
                pet: pet,
                species: pet.species.lowercased()
            )
            .onTapGesture {
                selectedPet = pet
                Haptics.softTap()
            }
        }
    }
    
    // MARK: - Viewport Filtering & Clustering
    
    /// Debounced update of visible pets to avoid excessive updates during pan/zoom
    private func debouncedUpdateVisiblePets() {
        debounceTask?.cancel()
        debounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(debounceDelay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            updateVisiblePets()
        }
    }
    
    /// Update visible pets based on current viewport bounds
    private func updateVisiblePets() {
        let visibleBounds = viewportBounds(for: region)
        
        // Filter liked pets that are within viewport bounds
        let petsInViewport = viewModel.liked.filter { pet in
            guard let coordinate = viewModel.coordinate(for: pet) else { return false }
            return coordinate.latitude >= visibleBounds.minLat &&
                   coordinate.latitude <= visibleBounds.maxLat &&
                   coordinate.longitude >= visibleBounds.minLon &&
                   coordinate.longitude <= visibleBounds.maxLon
        }
        
        visiblePets = petsInViewport
    }
    
    /// Calculate viewport bounds with padding to include pets near edges
    private func viewportBounds(for region: MKCoordinateRegion) -> (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) {
        let padding = region.span.latitudeDelta * 0.2 // 20% padding
        let minLat = region.center.latitude - (region.span.latitudeDelta / 2) - padding
        let maxLat = region.center.latitude + (region.span.latitudeDelta / 2) + padding
        let minLon = region.center.longitude - (region.span.longitudeDelta / 2) - padding
        let maxLon = region.center.longitude + (region.span.longitudeDelta / 2) + padding
        
        return (minLat, maxLat, minLon, maxLon)
    }
    
    /// Generate annotations (clusters or individual pets) based on zoom level
    private var annotations: [MapAnnotationItem] {
        let petsWithCoordinates = visiblePets.compactMap { pet -> (Pet, CLLocationCoordinate2D)? in
            guard let coordinate = viewModel.coordinate(for: pet) else { return nil }
            return (pet, coordinate)
        }
        
        guard !petsWithCoordinates.isEmpty else { return [] }
        
        // Limit the number of pets to process for performance
        let maxPetsToProcess = 500
        let petsToProcess = petsWithCoordinates.prefix(maxPetsToProcess)
        
        // Determine if we should cluster based on zoom level
        let shouldCluster = region.span.latitudeDelta > maxClusteringZoom
        let showAllIndividuals = region.span.latitudeDelta < minIndividualZoom
        
        if showAllIndividuals {
            // At close zoom, show all individual pets
            return Array(petsToProcess.map { pet, coordinate in
                MapAnnotationItem(pet: pet, coordinate: coordinate)
            })
        } else if shouldCluster {
            // At far zoom, cluster nearby pets
            return createClusters(from: Array(petsToProcess))
        } else {
            // At medium zoom, show individual pets (no clustering)
            return Array(petsToProcess.map { pet, coordinate in
                MapAnnotationItem(pet: pet, coordinate: coordinate)
            })
        }
    }
    
    /// Create clusters from pets using simplified distance-based clustering
    /// Optimized to limit computations for performance
    private func createClusters(from petsWithCoordinates: [(Pet, CLLocationCoordinate2D)]) -> [MapAnnotationItem] {
        guard petsWithCoordinates.count > 1 else {
            // If only one or zero pets, return individual annotation
            return petsWithCoordinates.map { pet, coordinate in
                MapAnnotationItem(pet: pet, coordinate: coordinate)
            }
        }
        
        // Dynamic cluster radius based on zoom level
        let zoomFactor = max(0.1, min(1.0, (region.span.latitudeDelta - minIndividualZoom) / (maxClusteringZoom - minIndividualZoom)))
        let currentClusterRadius = clusterRadiusMeters * zoomFactor
        
        // Use simplified grid-based approach for better performance
        // Group by approximate grid cells to reduce comparisons
        let gridSize = currentClusterRadius * 1.5
        var gridMap: [Int: [(Pet, CLLocationCoordinate2D)]] = [:]
        
        // Simple grid hashing
        for (pet, coordinate) in petsWithCoordinates {
            // Convert to approximate grid coordinates
            let gridLat = Int((coordinate.latitude + 90) * 100)
            let gridLon = Int((coordinate.longitude + 180) * 100)
            let cellSize = Int(gridSize / 1000) // Approximate grid cell size
            let gridKey = (gridLat / cellSize) * 10000 + (gridLon / cellSize)
            
            if gridMap[gridKey] == nil {
                gridMap[gridKey] = []
            }
            gridMap[gridKey]?.append((pet, coordinate))
        }
        
        var clusters: [PetCluster] = []
        var processedPets: Set<String> = []
        
        // Process grid cells - only compare pets within same or adjacent cells
        for (_, cellPets) in gridMap {
            for (pet, coordinate) in cellPets {
                if processedPets.contains(pet.id) { continue }
                
                // Find nearby pets in same cell
                var clusterPets: [(Pet, CLLocationCoordinate2D)] = [(pet, coordinate)]
                processedPets.insert(pet.id)
                
                // Only check pets in same cell (much smaller set)
                for (otherPet, otherCoordinate) in cellPets {
                    if processedPets.contains(otherPet.id) { continue }
                    
                    let distance = distanceBetween(coordinate, otherCoordinate)
                    if distance <= currentClusterRadius {
                        clusterPets.append((otherPet, otherCoordinate))
                        processedPets.insert(otherPet.id)
                    }
                }
                
                // Only create cluster if more than one pet
                if clusterPets.count > 1 {
                    let cluster = createCluster(from: clusterPets)
                    clusters.append(cluster)
                }
            }
        }
        
        // Create annotations for clusters
        var annotations: [MapAnnotationItem] = clusters.map { cluster in
            MapAnnotationItem(cluster: cluster, coordinate: cluster.coordinate)
        }
        
        // Add individual pets that weren't clustered
        let clusteredPetIds = Set(clusters.flatMap { $0.pets.map { $0.id } })
        for (pet, coordinate) in petsWithCoordinates where !clusteredPetIds.contains(pet.id) {
            annotations.append(MapAnnotationItem(pet: pet, coordinate: coordinate))
        }
        
        return annotations
    }
    
    /// Helper to calculate distance between two coordinates in meters
    private func distanceBetween(_ coord1: CLLocationCoordinate2D, _ coord2: CLLocationCoordinate2D) -> Double {
        let location1 = CLLocation(latitude: coord1.latitude, longitude: coord1.longitude)
        let location2 = CLLocation(latitude: coord2.latitude, longitude: coord2.longitude)
        return location1.distance(from: location2)
    }
    
    /// Helper to create a cluster from a group of pets
    private func createCluster(from pets: [(Pet, CLLocationCoordinate2D)]) -> PetCluster {
        let avgLat = pets.map { $0.1.latitude }.reduce(0, +) / Double(pets.count)
        let avgLon = pets.map { $0.1.longitude }.reduce(0, +) / Double(pets.count)
        let clusterCoordinate = CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon)
        
        return PetCluster(
            id: UUID().uuidString,
            pets: pets.map { $0.0 },
            coordinate: clusterCoordinate
        )
    }
    
    private func loadPetCoordinates() {
        guard !isLoadingCoordinates else { return }
        isLoadingCoordinates = true
        
        Task {
            // Preload coordinates for liked pets only
            await preloadLikedPetCoordinates()
            
            await MainActor.run {
                isLoadingCoordinates = false
                
                // Update map region to show liked pets
                let coordinates = viewModel.liked.compactMap { viewModel.coordinate(for: $0) }
                if !coordinates.isEmpty {
                    let minLat = coordinates.map { $0.latitude }.min() ?? region.center.latitude
                    let maxLat = coordinates.map { $0.latitude }.max() ?? region.center.latitude
                    let minLon = coordinates.map { $0.longitude }.min() ?? region.center.longitude
                    let maxLon = coordinates.map { $0.longitude }.max() ?? region.center.longitude
                    
                    let centerLat = (minLat + maxLat) / 2
                    let centerLon = (minLon + maxLon) / 2
                    let latDelta = max((maxLat - minLat) * 1.3, 0.1)
                    let lonDelta = max((maxLon - minLon) * 1.3, 0.1)
                    
                    withAnimation {
                        region = MKCoordinateRegion(
                            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
                        )
                    }
                }
            }
        }
    }
    
    /// Preload coordinates for liked pets only
    private func preloadLikedPetCoordinates() async {
        let likedPets = viewModel.liked
        let locationManager = LocationManager()
        
        // Process in batches to avoid rate limiting
        let batchSize = 10
        for i in stride(from: 0, to: likedPets.count, by: batchSize) {
            let endIndex = min(i + batchSize, likedPets.count)
            let chunk = Array(likedPets[i..<endIndex])
            
            await withTaskGroup(of: (String, CLLocationCoordinate2D?).self) { group in
                for pet in chunk {
                    // Skip if coordinate already exists
                    if viewModel.coordinate(for: pet) != nil { continue }
                    
                    group.addTask {
                        let coordinate = await locationManager.geocode(city: pet.city, state: pet.state)
                        return (pet.id, coordinate)
                    }
                }
                
                // Collect results and update coordinate cache
                for await (petId, coordinate) in group {
                    guard let coordinate = coordinate else { continue }
                    viewModel.setCoordinate(coordinate, forPetId: petId)
                }
            }
            
            // Small delay between batches to avoid rate limiting
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
    }
    
    private func distanceForPet(_ pet: Pet) -> Double? {
        guard let petCoord = viewModel.coordinate(for: pet),
              let currentLoc = locationManager.currentLocation else { return nil }
        let location1 = CLLocation(latitude: currentLoc.coordinate.latitude, longitude: currentLoc.coordinate.longitude)
        let location2 = CLLocation(latitude: petCoord.latitude, longitude: petCoord.longitude)
        let distanceInMeters = location1.distance(from: location2)
        return distanceInMeters / 1609.34 // Convert to miles
    }
}

// MARK: - Annotation Types

private struct MapAnnotationItem: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let pet: Pet?
    let cluster: PetCluster?
    
    init(pet: Pet, coordinate: CLLocationCoordinate2D) {
        self.id = pet.id
        self.coordinate = coordinate
        self.pet = pet
        self.cluster = nil
    }
    
    init(cluster: PetCluster, coordinate: CLLocationCoordinate2D) {
        self.id = cluster.id
        self.coordinate = coordinate
        self.pet = nil
        self.cluster = cluster
    }
}

private struct PetCluster: Identifiable {
    let id: String
    let pets: [Pet]
    let coordinate: CLLocationCoordinate2D
    
    var count: Int {
        pets.count
    }
}

// MARK: - Pin Views

private struct ClusterPin: View {
    let cluster: PetCluster
    
    var body: some View {
        ZStack {
            Circle()
                .fill(PMColor.coral)
                .frame(width: 50, height: 50)
                .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 3)
            
            Text("\(cluster.count)")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

private struct PetMapPin: View {
    let pet: Pet
    let species: String
    
    var body: some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 44, height: 44)
                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
            
            Image(systemName: pinIcon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(pinColor)
        }
    }
    
    private var pinIcon: String {
        switch species {
        case "dog", "dogs":
            return "pawprint.fill"
        case "cat", "cats":
            return "cat.fill"
        default:
            return "pawprint.fill"
        }
    }
    
    private var pinColor: Color {
        switch species {
        case "dog", "dogs":
            return PMColor.coral
        case "cat", "cats":
            return PMColor.mint
        default:
            return PMColor.gold
        }
    }
}

// MARK: - Detail Views

private struct ClusterDetailView: View {
    let cluster: PetCluster
    let onSelectPet: (Pet) -> Void
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("\(cluster.count) pets in this area")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(PMColor.textSecondary)
                }
                
                ForEach(cluster.pets) { pet in
                    Button {
                        onSelectPet(pet)
                    } label: {
                        HStack(spacing: 12) {
                            AsyncImage(url: pet.thumbnail) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle()
                                    .fill(PMColor.secondarySurface)
                                    .overlay(
                                        Image(systemName: pet.isCat ? "cat.fill" : "pawprint.fill")
                                            .foregroundStyle(PMColor.textTertiary)
                                    )
                            }
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(pet.name)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(PMColor.textPrimary)
                                
                                Text(pet.breedDisplay)
                                    .font(.system(size: 14))
                                    .foregroundStyle(PMColor.textSecondary)
                                
                                Text(pet.locationDisplay)
                                    .font(.system(size: 12))
                                    .foregroundStyle(PMColor.textTertiary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(PMColor.textTertiary)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Pets in Area")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct PetMapPreviewCard: View {
    let pet: Pet
    let distance: Double?
    let onTap: () -> Void
    let onViewDetails: () -> Void
    
    var body: some View {
        Button(action: onViewDetails) {
            HStack(spacing: 12) {
                // Pet image
                AsyncImage(url: pet.thumbnail) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(PMColor.secondarySurface)
                        .overlay(
                            Image(systemName: pet.isCat ? "cat.fill" : "pawprint.fill")
                                .foregroundStyle(PMColor.textTertiary)
                        )
                }
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                
                // Pet info
                VStack(alignment: .leading, spacing: 6) {
                    Text(pet.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(PMColor.textPrimary)
                    
                    Text(pet.breedDisplay)
                        .font(.system(size: 14))
                        .foregroundStyle(PMColor.textSecondary)
                    
                    if let distance = distance {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 12))
                            Text(String(format: "%.1f mi away", distance))
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(PMColor.coral)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PMColor.textTertiary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

