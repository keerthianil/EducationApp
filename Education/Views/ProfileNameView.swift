//
//  ProfileNameView.swift
//  Education
//
//  Created by Keerthi Reddy on 10/28/25.
//

import SwiftUI
import Combine

struct ProfileNameView: View {
    @EnvironmentObject var app: AppState
    @StateObject private var vm = ProfileViewModel()
    private let total = 3, step = 1

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            StepProgress(current: step, total: total).padding(.top)
            ScreenHeader(title: "What’s your name?")
                .accessibilityHint("Double tap to edit the text field below")

            TextField("Your name", text: $vm.name)
                .textContentType(.name)
                .submitLabel(.done)
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).stroke(.secondary))
                .accessibilityHint("Enter your name")

            Spacer()

            HStack {
                Spacer()
                Button {
                    app.name = vm.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    app.route = .profileAge
                } label: { HStack { Text("Next"); Image(systemName: "arrow.right") } }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!vm.canContinueFromName)
                .accessibilityHint("Moves to age selection")
            }
        }
        .padding()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    app.route = .login
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
                .accessibilityLabel("Back")
                .accessibilityHint("Goes to Login")
            }
        }
        .onAppear {
            UIAccessibility.post(notification: .announcement,
                                 argument: "Profile setup. Step \(step) of \(total). What is your name?")
        }
    }
}
