//
//  LauncherView.swift
//  Education
//
//  Main launcher screen - Choose between Design System or App
//

import SwiftUI

struct LauncherView: View {
    @State private var navigateToDesignSystem = false
    @State private var navigateToApp = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                ColorTokens.background
                    .ignoresSafeArea()
                
                // Content
                VStack(spacing: Spacing.xxLarge) {
                    Spacer()
                    
                    // App Logo/Title
                    VStack(spacing: Spacing.medium) {
                        Image(systemName: "app.dashed")
                            .font(.system(size: 80))
                            .foregroundColor(ColorTokens.primary)
                        
                        Text("StemA11y")
                            .font(Typography.largeTitle)
                            .foregroundColor(ColorTokens.textPrimary)
                        
                        Text("Accessible STEM Education")
                            .font(Typography.body)
                            .foregroundColor(ColorTokens.textSecondary)
                    }
                    
                    Spacer()
                    
                    // Navigation Buttons
                    VStack(spacing: Spacing.medium) {
                        // Design System Button
                        NavigationLink(destination: ShowcaseHomeView()) {
                            HStack {
                                Image(systemName: "paintpalette.fill")
                                    .font(.title2)
                                
                                Text("Design System")
                                    .font(Typography.bodyBold)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                            }
                            .foregroundColor(ColorTokens.textLight)
                            .padding(Spacing.medium)
                            .frame(maxWidth: .infinity)
                            .frame(height: Spacing.buttonHeight)
                            .background(ColorTokens.primary)
                            .cornerRadius(Spacing.cornerRadius)
                        }
                        .accessibilityLabel("View Design System Components")
                        .accessibilityHint("Shows all UI components and design tokens")
                        
                        // Launch App Button
                        NavigationLink(destination: AboutView()) {
                            HStack {
                                Image(systemName: "rocket.fill")
                                    .font(.title2)
                                
                                Text("Launch App")
                                    .font(Typography.bodyBold)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                            }
                            .foregroundColor(ColorTokens.textLight)
                            .padding(Spacing.medium)
                            .frame(maxWidth: .infinity)
                            .frame(height: Spacing.buttonHeight)
                            .background(ColorTokens.secondaryPink)
                            .cornerRadius(Spacing.cornerRadius)
                        }
                        .accessibilityLabel("Launch Application")
                        .accessibilityHint("Starts the onboarding flow")
                    }
                    
                    Spacer()
                        .frame(height: Spacing.xxLarge)
                }
                .padding(Spacing.screenPadding)
            }
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    LauncherView()
}