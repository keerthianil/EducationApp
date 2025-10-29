//
//  TutorialView.swift
//  Education
//
//  Created by Keerthi Reddy on 10/28/25.
//
import SwiftUI
import Combine

struct TutorialView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var speech: SpeechService
    @EnvironmentObject var haptics: HapticService

    private let total = 3, step = 3
    private let demoEquation = "Start equation. x squared plus y squared equals one. End equation."

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                ScreenHeader(title: "Tutorial")

                ZStack {
                    RoundedRectangle(cornerRadius: 16).fill(Color.secondary.opacity(0.1)).frame(height: 200)
                    Image(systemName: "rectangle.on.rectangle.angled")
                        .font(.system(size: 56)).foregroundColor(.secondary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Tutorial image")

                Text("Learn how to explore equations with VoiceOver and haptics. Tap the buttons below to hear a demo and feel a term cue.")
                    .font(.body)

                HStack {
                    Button("Speak Example") {
                        haptics.mathStart()
                        speech.speak(demoEquation)
                        haptics.mathEnd()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityHint("Reads a simple equation")

                    Button("Term Haptic") { haptics.mathTerm() }
                        .buttonStyle(PrimaryButtonStyle())
                        .accessibilityHint("Plays a haptic cue for a math term")
                }

                HStack {
                    Button("Skip") { app.route = .home }.buttonStyle(PrimaryButtonStyle())
                    Button("Next") { app.route = .home }.buttonStyle(PrimaryButtonStyle())
                }
                .accessibilityHint("Continue to Home")
            }
            .padding()
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    app.route = .profileAge
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
                .accessibilityLabel("Back")
                .accessibilityHint("Goes to What’s your age")
            }
        }
        .onAppear {
            UIAccessibility.post(notification: .announcement, argument: "Tutorial. Step \(step) of \(total).")
        }
    }
}
