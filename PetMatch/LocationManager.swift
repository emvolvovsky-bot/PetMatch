//
//  LocationManager.swift
//  PetMatch
//
//  Created for location services and geocoding
//

import Foundation
import CoreLocation
import MapKit

@MainActor
class LocationManager: NSObject, ObservableObject {
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocation?
    @Published var isLocating = false
    
    private let locationManager = CLLocationManager()
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = locationManager.authorizationStatus
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func requestCurrentLocation() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            requestLocationPermission()
            return
        }
        
        isLocating = true
        locationManager.requestLocation()
    }
    
    // Geocode city and state to coordinates
    func geocode(city: String?, state: String?) async -> CLLocationCoordinate2D? {
        guard let city = city, !city.isEmpty else { return nil }
        
        let addressString: String
        if let state = state, !state.isEmpty {
            addressString = "\(city), \(state), USA"
        } else {
            addressString = "\(city), USA"
        }
        
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.geocodeAddressString(addressString)
            if let location = placemarks.first?.location {
                return location.coordinate
            }
        } catch {
            print("Geocoding error: \(error.localizedDescription)")
        }
        return nil
    }
    
    // Reverse geocode coordinates to address
    func reverseGeocode(coordinate: CLLocationCoordinate2D) async -> String? {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                var components: [String] = []
                if let city = placemark.locality {
                    components.append(city)
                }
                if let state = placemark.administrativeArea {
                    components.append(state)
                }
                return components.isEmpty ? nil : components.joined(separator: ", ")
            }
        } catch {
            print("Reverse geocoding error: \(error.localizedDescription)")
        }
        return nil
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            if let location = locations.first {
                self.currentLocation = location
                self.isLocating = false
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.isLocating = false
            print("Location error: \(error.localizedDescription)")
        }
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
        }
    }
}

// MARK: - Distance Calculation

/// Calculate distance in miles between two coordinates
func distanceInMiles(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
    let location1 = CLLocation(latitude: from.latitude, longitude: from.longitude)
    let location2 = CLLocation(latitude: to.latitude, longitude: to.longitude)
    
    let distanceInMeters = location1.distance(from: location2)
    let distanceInMiles = distanceInMeters / 1609.34 // Convert meters to miles
    return distanceInMiles
}

/// Helper to geocode a pet's location
func geocodePetLocation(pet: Pet, locationManager: LocationManager) async -> CLLocationCoordinate2D? {
    return await locationManager.geocode(city: pet.city, state: pet.state)
}

