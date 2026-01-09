//
//  PetMatchApp.swift
//  PetMatch
//
//  Created by Emil Volvovsky on 1/5/26.
//

import SwiftUI

@main
struct PetMatchApp: App {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    
    var body: some Scene {
        WindowGroup {
            if hasSeenOnboarding {
                ContentView()
            } else {
                OnboardingView(hasSeenOnboarding: $hasSeenOnboarding)
            }
        }
    }
}
