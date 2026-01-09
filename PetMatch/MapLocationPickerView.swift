//
//  MapLocationPickerView.swift
//  PetMatch
//
//  Map view for selecting location and radius in filters
//

import SwiftUI
import MapKit

struct MapLocationPickerView: View {
    @Binding var selectedCoordinate: CLLocationCoordinate2D?
    @Binding var radiusMiles: Double
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationManager = LocationManager()
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), // Default: San Francisco
        span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
    )
    @State private var mapCoordinate: CLLocationCoordinate2D?
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Map(coordinateRegion: $region)
                    .onChange(of: region.center.latitude) { _, _ in
                        // Update coordinate when map is dragged or panned
                        let newCenter = region.center
                        mapCoordinate = newCenter
                        selectedCoordinate = newCenter
                    }
                    .onChange(of: region.center.longitude) { _, _ in
                        // Update coordinate when map is dragged or panned
                        let newCenter = region.center
                        mapCoordinate = newCenter
                        selectedCoordinate = newCenter
                    }
                
                // Fixed center pin that always stays on screen
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        ZStack {
                            // Red circle background
                            Circle()
                                .fill(PMColor.coral)
                                .frame(width: 32, height: 32)
                            
                            // White pin point
                            Image(systemName: "mappin")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .offset(y: -20) // Offset to center the pin point on the map center
                        Spacer()
                    }
                    Spacer()
                }
                .allowsHitTesting(false) // Don't block map interactions
                
                // Controls overlay
                VStack(spacing: 16) {
                    // Current location button
                    HStack {
                        Spacer()
                        Button {
                            locationManager.requestCurrentLocation()
                        } label: {
                            Image(systemName: "location.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(14)
                                .background(PMColor.coral)
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 20)
                        .padding(.top, 20)
                    }
                    
                    Spacer()
                    
                    // Radius selector
                    VStack(spacing: 12) {
                        Text("Search Radius")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(PMColor.textPrimary)
                        
                        // Slider
                        VStack(spacing: 8) {
                            Slider(
                                value: $radiusMiles,
                                in: 1...100,
                                step: 1
                            )
                            .tint(PMColor.coral)
                            
                            Text("\(Int(radiusMiles)) miles")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(PMColor.textSecondary)
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 20)
                    .padding(.horizontal, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Select Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(PMColor.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if let coord = mapCoordinate ?? selectedCoordinate {
                            selectedCoordinate = coord
                        }
                        Haptics.softTap()
                        dismiss()
                    }
                    .foregroundStyle(PMColor.coral)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                // Initialize with existing coordinate or current location
                if let coord = selectedCoordinate {
                    mapCoordinate = coord
                    region.center = coord
                } else if let currentLoc = locationManager.currentLocation {
                    let coord = currentLoc.coordinate
                    mapCoordinate = coord
                    selectedCoordinate = coord
                    region.center = coord
                }
            }
            .onChange(of: locationManager.currentLocation) { _, newLocation in
                if let location = newLocation, selectedCoordinate == nil {
                    let coord = location.coordinate
                    mapCoordinate = coord
                    selectedCoordinate = coord
                    withAnimation {
                        region.center = coord
                    }
                }
            }
        }
    }
}

