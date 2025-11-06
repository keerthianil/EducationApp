//
//  ColorShowcaseView.swift
//  Education
//

import SwiftUI

struct ColorShowcaseView: View {
    var body: some View {
        ZStack {
            ColorTokens.background
                .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xLarge) {
                    // Primary Colors
                    ColorSection(title: "Primary Colors") {
                        ColorSwatch(name: "Primary", color: ColorTokens.primary, hex: "#1C636F")
                        ColorSwatch(name: "Primary Light 1", color: ColorTokens.primaryLight1, hex: "#6FA9B3")
                        ColorSwatch(name: "Primary Light 2", color: ColorTokens.primaryLight2, hex: "#A5CDD3")
                        ColorSwatch(name: "Primary Light 3", color: ColorTokens.primaryLight3, hex: "#DCF0F2")
                    }
                    
                    // Secondary - Pink
                    ColorSection(title: "Secondary - Pink") {
                        ColorSwatch(name: "Secondary Pink", color: ColorTokens.secondaryPink, hex: "#9C265D")
                        ColorSwatch(name: "Pink Light 1", color: ColorTokens.secondaryPinkLight1, hex: "#D96FA5")
                        ColorSwatch(name: "Pink Light 2", color: ColorTokens.secondaryPinkLight2, hex: "#E89FC2")
                        ColorSwatch(name: "Pink Light 3", color: ColorTokens.secondaryPinkLight3, hex: "#F8D9E9")
                    }
                    
                    // Semantic Colors
                    ColorSection(title: "Semantic Colors") {
                        ColorSwatch(name: "Success", color: ColorTokens.success, hex: "#208515")
                        ColorSwatch(name: "Error", color: ColorTokens.error, hex: "#B31111")
                        ColorSwatch(name: "Warning", color: ColorTokens.warning, hex: "#FFB921")
                        ColorSwatch(name: "Info", color: ColorTokens.info, hex: "#214F9A")
                    }
                    
                    // Neutral Colors
                    ColorSection(title: "Neutral Colors") {
                        ColorSwatch(name: "Background", color: ColorTokens.background, hex: "#F5F5F5")
                        ColorSwatch(name: "Surface 1", color: ColorTokens.surface1, hex: "#ECECEC")
                        ColorSwatch(name: "Surface 2", color: ColorTokens.surface2, hex: "#E3E3E3")
                        ColorSwatch(name: "Text Dark", color: ColorTokens.textDark, hex: "#212121")
                    }
                }
                .padding(Spacing.screenPadding)
            }
        }
        .navigationTitle("Colors")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ColorSection<Content: View>: View {
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
            
            VStack(spacing: Spacing.xSmall) {
                content
            }
        }
    }
}

struct ColorSwatch: View {
    let name: String
    let color: Color
    let hex: String
    
    var body: some View {
        HStack(spacing: Spacing.small) {
            RoundedRectangle(cornerRadius: Spacing.cornerRadiusSmall)
                .fill(color)
                .frame(width: 60, height: 44)
                .overlay(
                    RoundedRectangle(cornerRadius: Spacing.cornerRadiusSmall)
                        .stroke(ColorTokens.border, lineWidth: 1)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(Typography.body)
                    .foregroundColor(ColorTokens.textPrimary)
                
                Text(hex)
                    .font(Typography.caption1)
                    .foregroundColor(ColorTokens.textSecondary)
            }
            
            Spacer()
        }
        .padding(Spacing.small)
        .background(ColorTokens.surface1)
        .cornerRadius(Spacing.cornerRadiusSmall)
    }
}

#Preview {
    NavigationStack {
        ColorShowcaseView()
    }
}