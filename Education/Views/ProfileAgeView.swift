//
//  ProfileAgeView.swift
//  Education
//
//  Created by Keerthi Reddy on 10/28/25.
//
import SwiftUI
import Combine

struct ProfileAgeView: View {
    @EnvironmentObject var app: AppState
    @StateObject private var vm = ProfileViewModel()
    private let total = 3, step = 2

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            StepProgress(current: step, total: total).padding(.top)
            ScreenHeader(title: "What’s your age?")

            VStack(spacing: Theme.Spacing.sm) {
                ForEach(AgeBucket.allCases) { b in
                    SelectChip(title: b.description, isSelected: vm.selectedAge == b) { vm.selectedAge = b }
                        .accessibilitySortPriority(vm.selectedAge == b ? 1 : 0)
                }
            }

            Spacer()

            HStack {
                Button { app.route = .profileName } label: { Label("Prev", systemImage: "arrow.left") }
                    .buttonStyle(PrimaryButtonStyle())

                Button {
                    app.age = vm.selectedAge
                    app.route = .tutorial
                } label: { HStack { Text("Next"); Image(systemName: "arrow.right") } }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!vm.canContinueFromAge)
            }
        }
        .padding()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    app.route = .profileName
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
                .accessibilityLabel("Back")
                .accessibilityHint("Goes to What’s your name")
            }
        }
        .onAppear {
            UIAccessibility.post(notification: .announcement,
                                 argument: "Profile setup. Step \(step) of \(total). Select your age.")
        }
    }
}
