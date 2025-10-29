//
//  AboutView.swift
//  Education
//
//  Created by Keerthi Reddy on 10/28/25.
//
import SwiftUI
import Combine

struct AboutView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                ScreenHeader(title: "education")

                ZStack {
                    RoundedRectangle(cornerRadius: 16).fill(Color.secondary.opacity(0.1)).frame(height: 220)
                    Image(systemName: "laptopcomputer.and.iphone")
                        .font(.system(size: 64)).foregroundColor(.secondary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Illustration: student using devices")

                // 2–3 concise lines
                Text("""
                     Accessible STEM learning for blind and low-vision students.
                     Explore lessons with VoiceOver, clear speech, and helpful haptics.
                     Works on iPhone and iPad.
                     """)
                .font(.body)

                Button("Get Started") {
                    app.route = .login
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityHint("Opens login")
            }
            .padding()
        }
        .onAppear {
            UIAccessibility.post(notification: .announcement, argument: "education. Get Started to continue.")
        }
        // No back button on the first screen by design
    }
}
