//
//  AppState.swift
//  Education
//
//  Created by Keerthi Reddy on 10/28/25.
//

import Foundation
import Combine
import SwiftUI

final class AppState: ObservableObject {
    enum Route: Hashable {
        case about
        case login
        case profileName
        case profileAge
        case tutorial
        case chooseFlow
        case home
    }
    
    @Published var route: Route = .about
    @Published var name: String = ""
    @Published var selectedFlow: Int = 1
    
    // Persist onboarding completion
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    
    func completeOnboarding() {
        hasCompletedOnboarding = true
    }
    
    func resetOnboarding() {
        hasCompletedOnboarding = false
    }
}
