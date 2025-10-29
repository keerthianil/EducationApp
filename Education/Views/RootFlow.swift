//
//  RootFlow.swift
//  Education
//
//  Created by Keerthi Reddy on 10/28/25.
//

import SwiftUI
import Combine

struct RootFlow: View {
    @EnvironmentObject var app: AppState
    var body: some View {
        NavigationStack {
            switch app.route {
            case .about:        AboutView()
            case .login:        LoginView()
            case .profileName:  ProfileNameView()
            case .profileAge:   ProfileAgeView()
            case .tutorial:     TutorialView()
            case .home:         HomeView()
            }
        }
    }
}
