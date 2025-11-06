//
//  ButtonShowcaseView.swift
//  Education
//

import SwiftUI

struct ButtonShowcaseView: View {
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            ColorTokens.background
                .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xLarge) {
                    Text("Button Styles")
                        .font(Typography.heading2)
                        .foregroundColor(ColorTokens.textPrimary)
                    
                    // Primary Buttons
                    ButtonSection(title: "Primary Buttons") {
                        Button("Primary Button") {}
                            .buttonStyle(PrimaryButtonStyle())
                        
                        Button("Primary Disabled") {}
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(true)
                    }
                    
                    // Secondary Buttons
                    ButtonSection(title: "Secondary Buttons") {
                        Button("Secondary Button") {}
                            .buttonStyle(SecondaryButtonStyle())
                        
                        Button("Secondary Disabled") {}
                            .buttonStyle(SecondaryButtonStyle())
                            .disabled(true)
                    }
                    
                    // Icon Buttons
                    ButtonSection(title: "Icon Buttons") {
                        HStack(spacing: Spacing.small) {
                            Button(action: {}) {
                                Image(systemName: "heart.fill")
                            }
                            .buttonStyle(IconButtonStyle())
                            
                            Button(action: {}) {
                                Image(systemName: "star.fill")
                            }
                            .buttonStyle(IconButtonStyle())
                            
                            Button(action: {}) {
                                Image(systemName: "bookmark.fill")
                            }
                            .buttonStyle(IconButtonStyle())
                        }
                    }
                }
                .padding(Spacing.screenPadding)
            }
        }
        .navigationTitle("Buttons")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ButtonSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text(title)
                .font(Typography.heading3)
                .foregroundColor(ColorTokens.textPrimary)
            
            VStack(spacing: Spacing.small) {
                content
            }
        }
    }
}

// Button Styles
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.bodyBold)
            .foregroundColor(ColorTokens.textLight)
            .frame(maxWidth: .infinity)
            .frame(height: Spacing.buttonHeight)
            .background(ColorTokens.primary)
            .cornerRadius(Spacing.cornerRadius)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.bodyBold)
            .foregroundColor(ColorTokens.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: Spacing.buttonHeight)
            .background(ColorTokens.surface1)
            .cornerRadius(Spacing.cornerRadius)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title2)
            .foregroundColor(ColorTokens.primary)
            .frame(width: Spacing.minTouchTarget, height: Spacing.minTouchTarget)
            .background(ColorTokens.primaryLight3)
            .cornerRadius(Spacing.cornerRadiusSmall)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

#Preview {
    NavigationStack {
        ButtonShowcaseView()
    }
}