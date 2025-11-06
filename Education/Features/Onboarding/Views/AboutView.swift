//
//  AboutView.swift
//  Education
//
//  First screen in onboarding flow
//

import SwiftUI

struct AboutView: View {
    @State private var navigateToNext = false
    
    var body: some View {
        ZStack {
            // Background
            ColorTokens.background
                .ignoresSafeArea()
            
            // Content
            VStack(spacing: Spacing.xLarge) {
                Spacer()
                
                // Icon
                Image(systemName: "book.fill")
                    .font(.system(size: 80))
                    .foregroundColor(ColorTokens.primary)
                
                // Title
                VStack(spacing: Spacing.small) {
                    Text("Welcome to StemA11y")
                        .font(Typography.largeTitle)
                        .foregroundColor(ColorTokens.textPrimary)
                        .multilineTextAlignment(.center)
                    
                    Text("Making STEM education accessible for everyone")
                        .font(Typography.body)
                        .foregroundColor(ColorTokens.textSecondary)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
                
                // Features
                VStack(alignment: .leading, spacing: Spacing.medium) {
                    FeatureRow(
                        icon: "waveform",
                        title: "Audio Feedback",
                        description: "Text-to-speech for all content"
                    )
                    
                    FeatureRow(
                        icon: "hand.tap.fill",
                        title: "Haptic Cues",
                        description: "Touch feedback for navigation"
                    )
                    
                    FeatureRow(
                        icon: "accessibility",
                        title: "VoiceOver Support",
                        description: "Full accessibility features"
                    )
                }
                .padding(Spacing.large)
                .background(ColorTokens.surface1)
                .cornerRadius(Spacing.cornerRadius)
                
                Spacer()
                
                // Continue Button
                Button("Get Started") {
                    navigateToNext = true
                }
                .font(Typography.bodyBold)
                .foregroundColor(ColorTokens.textLight)
                .frame(maxWidth: .infinity)
                .frame(height: Spacing.buttonHeight)
                .background(ColorTokens.primary)
                .cornerRadius(Spacing.cornerRadius)
                .accessibilityLabel("Get Started")
                .accessibilityHint("Continue to next screen")
            }
            .padding(Spacing.screenPadding)
        }
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $navigateToNext) {
            Text("Next screen coming soon!")
                .font(Typography.largeTitle)
        }
    }
}

// Feature Row Component
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: Spacing.medium) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(ColorTokens.primary)
                .frame(width: 40, height: 40)
                .background(ColorTokens.primaryLight3)
                .cornerRadius(Spacing.cornerRadiusSmall)
            
            VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                Text(title)
                    .font(Typography.bodyBold)
                    .foregroundColor(ColorTokens.textPrimary)
                
                Text(description)
                    .font(Typography.footnote)
                    .foregroundColor(ColorTokens.textSecondary)
            }
            
            Spacer()
        }
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
