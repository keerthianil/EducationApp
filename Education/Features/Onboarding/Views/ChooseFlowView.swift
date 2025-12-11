//
//  ChooseFlowView.swift
//  Education
//
//  Features/Onboarding/Views/ChooseFlowView.swift
//

import SwiftUI
import UIKit

struct ChooseFlowView: View {
    @EnvironmentObject var appState: AppState
    @State private var goToDashboard = false
    @State private var didAnnounceScreen = false
    @AccessibilityFocusState private var flow1Focused: Bool
    
    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                    .frame(height: 50)
                
                Text("Choose a Flow")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(ColorTokens.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                
                Text("Select a dashboard layout for A/B testing")
                    .font(.custom("Arial", size: 15))
                    .foregroundColor(Color(hex: "#61758A"))
                    .multilineTextAlignment(.center)
                
                Spacer()
                    .frame(height: 20)
                
                VStack(spacing: 12) {
                    // Flow 1 - Current Design
                    FlowSelectionButton(
                        flowNumber: 1,
                        title: "Flow 1",
                        subtitle: "Bottom tabs + Vertical menu",
                        isEnabled: true
                    ) {
                        appState.selectedFlow = 1
                        appState.completeOnboarding()
                        goToDashboard = true
                    }
                    .accessibilityFocused($flow1Focused)
                    
                    // Flow 2 - Top tabs design
                    FlowSelectionButton(
                        flowNumber: 2,
                        title: "Flow 2",
                        subtitle: "Top tabs (Home/All files)",
                        isEnabled: true
                    ) {
                        appState.selectedFlow = 2
                        appState.completeOnboarding()
                        goToDashboard = true
                    }
                    
                    // Flow 3 - Upload tabs design
                    FlowSelectionButton(
                        flowNumber: 3,
                        title: "Flow 3",
                        subtitle: "Upload/Teacher/Recent tabs + Side menu",
                        isEnabled: true
                    ) {
                        appState.selectedFlow = 3
                        appState.completeOnboarding()
                        goToDashboard = true
                    }
                }
                .padding(.horizontal, 32)
                
                Spacer()
            }
            
            // Navigation based on selected flow
            NavigationLink(
                destination: destinationView(),
                isActive: $goToDashboard
            ) {
                EmptyView()
            }
            .hidden()
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            guard !didAnnounceScreen else { return }
            didAnnounceScreen = true
            
            UIAccessibility.post(notification: .announcement, argument: "Choose a Flow. All 3 flows are available for testing.")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                flow1Focused = true
            }
        }
    }
    
    @ViewBuilder
    private func destinationView() -> some View {
        switch appState.selectedFlow {
        case 1:
            DashboardView()
                .navigationBarBackButtonHidden(true)
        case 2:
            DashboardFlow2View()
                .navigationBarBackButtonHidden(true)
        case 3:
            DashboardFlow3View()
                .navigationBarBackButtonHidden(true)
        default:
            DashboardView()
                .navigationBarBackButtonHidden(true)
        }
    }
}

// MARK: - Flow Selection Button

private struct FlowSelectionButton: View {
    let flowNumber: Int
    let title: String
    let subtitle: String
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.custom("Arial", size: 12))
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .background(isEnabled ? ColorTokens.primary : ColorTokens.primary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!isEnabled)
        .accessibilityLabel("\(title). \(subtitle)")
        .accessibilityHint(isEnabled ? "Double tap to select this flow" : "Not available")
    }
}

#Preview {
    NavigationStack {
        ChooseFlowView()
            .environmentObject(AppState())
    }
}
