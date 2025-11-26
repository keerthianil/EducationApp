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
            
            // Hidden navigation to Dashboard
            NavigationLink(
                destination: DashboardView()
                    .navigationBarBackButtonHidden(true),
                isActive: $goToDashboard
            ) {
                EmptyView()
            }
            .hidden()
            
            VStack(spacing: 24) {
                Spacer()
                    .frame(height: 50)
                
                Text("Choose a Flow")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(ColorTokens.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                
                Spacer()
                    .frame(height: 20)
                
                VStack(spacing: 12) {
                    // Flow 1 - Active
                    Button {
                        appState.selectedFlow = 1
                        appState.completeOnboarding()
                        goToDashboard = true
                    } label: {
                        Text("Flow 1")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 72)
                            .background(ColorTokens.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .accessibilityLabel("Flow 1")
                    .accessibilityHint("Double tap to select Flow 1 and continue to the dashboard")
                    .accessibilityFocused($flow1Focused)
                    
                    // Flow 2 - Disabled
                    Button {
                        // Not implemented
                    } label: {
                        Text("Flow 2")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 72)
                            .background(ColorTokens.primary.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(true)
                    .accessibilityLabel("Flow 2")
                    .accessibilityHint("Not available in this version")
                    
                    // Flow 3 - Disabled
                    Button {
                        // Not implemented
                    } label: {
                        Text("Flow 3")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 72)
                            .background(ColorTokens.primary.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(true)
                    .accessibilityLabel("Flow 3")
                    .accessibilityHint("Not available in this version")
                }
                .padding(.horizontal, 48)
                
                Spacer()
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            guard !didAnnounceScreen else { return }
            didAnnounceScreen = true
            
            UIAccessibility.post(notification: .announcement, argument: "Choose a Flow. Only Flow 1 is available.")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                flow1Focused = true
            }
        }
    }
}

#Preview {
    NavigationStack {
        ChooseFlowView()
            .environmentObject(AppState())
    }
}
