//
//  ShowcaseHomeView.swift
//  Education
//
//  Design System Showcase - Browse all components
//

import SwiftUI

struct ShowcaseHomeView: View {
    var body: some View {
        ZStack {
            ColorTokens.background
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: Spacing.large) {
                    // Header
                    VStack(spacing: Spacing.small) {
                        Text("Design System")
                            .font(Typography.largeTitle)
                            .foregroundColor(ColorTokens.textPrimary)
                        
                        Text("Explore all components and tokens")
                            .font(Typography.body)
                            .foregroundColor(ColorTokens.textSecondary)
                    }
                    .padding(.top, Spacing.large)
                    
                    // Component Cards
                    VStack(spacing: Spacing.medium) {
                        ShowcaseCard(
                            icon: "paintpalette.fill",
                            title: "Colors",
                            description: "All color tokens and palettes",
                            destination: ColorShowcaseView()
                        )
                        
                        ShowcaseCard(
                            icon: "textformat",
                            title: "Typography",
                            description: "Font styles and text scales",
                            destination: TypographyShowcaseView()
                        )
                        
                        ShowcaseCard(
                            icon: "square.on.square",
                            title: "Spacing",
                            description: "Layout spacing and sizing",
                            destination: SpacingShowcaseView()
                        )
                        
                        ShowcaseCard(
                            icon: "button.programmable",
                            title: "Buttons",
                            description: "Button styles and states",
                            destination: ButtonShowcaseView()
                        )
                    }
                }
                .padding(Spacing.screenPadding)
            }
        }
        .navigationTitle("Design System")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// Reusable Showcase Card
struct ShowcaseCard<Destination: View>: View {
    let icon: String
    let title: String
    let description: String
    let destination: Destination
    
    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: Spacing.medium) {
                // Icon
                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(ColorTokens.primary)
                    .frame(width: 50, height: 50)
                    .background(ColorTokens.primaryLight3)
                    .cornerRadius(Spacing.cornerRadiusSmall)
                
                // Text
                VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                    Text(title)
                        .font(Typography.headline)
                        .foregroundColor(ColorTokens.textPrimary)
                    
                    Text(description)
                        .font(Typography.footnote)
                        .foregroundColor(ColorTokens.textSecondary)
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .foregroundColor(ColorTokens.textTertiary)
            }
            .padding(Spacing.medium)
            .background(ColorTokens.surface1)
            .cornerRadius(Spacing.cornerRadius)
        }
    }
}

#Preview {
    NavigationStack {
        ShowcaseHomeView()
    }
}