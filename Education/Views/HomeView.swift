//
//  HomeView.swift
//  Education
//
//  Created by Keerthi Reddy on 10/28/25.
//

import SwiftUI
import Combine

struct HomeView: View {
    var body: some View {
        NavigationView {
            List {
                Section("Getting Started") {
                    Text("Upload a PDF (future)")
                    Text("Practice VoiceOver gestures")
                    Text("Adjust math settings (future)")
                }
            }
            .navigationTitle("education")
        }
    }
}
