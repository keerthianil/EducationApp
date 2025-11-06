//
//  TypographyShowcaseView.swift
//  Education
//

import SwiftUI

struct TypographyShowcaseView: View {
    var body: some View {
        ZStack {
            ColorTokens.background
                .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.large) {
                    Text("Typography Styles")
                        .font(Typography.heading2)
                        .foregroundColor(ColorTokens.textPrimary)
                    
                    VStack(alignment: .leading, spacing: Spacing.xLarge) {
                        // Titles
                        TypeStyleRow(
                            style: "Large Title",
                            font: Typography.largeTitle,
                            details: "Verdana Bold, 34pt"
                        )
                        
                        TypeStyleRow(
                            style: "Heading 1",
                            font: Typography.heading1,
                            details: "Verdana SemiBold, 28pt"
                        )
                        
                        TypeStyleRow(
                            style: "Heading 2",
                            font: Typography.heading2,
                            details: "Verdana Regular, 22pt"
                        )
                        
                        TypeStyleRow(
                            style: "Heading 3",
                            font: Typography.heading3,
                            details: "Verdana Regular, 20pt"
                        )
                        
                        Divider()
                        
                        // Body
                        TypeStyleRow(
                            style: "Headline",
                            font: Typography.headline,
                            details: "Verdana SemiBold, 17pt"
                        )
                        
                        TypeStyleRow(
                            style: "Body",
                            font: Typography.body,
                            details: "System Regular, 17pt"
                        )
                        
                        TypeStyleRow(
                            style: "Body Bold",
                            font: Typography.bodyBold,
                            details: "System SemiBold, 17pt"
                        )
                        
                        Divider()
                        
                        // Small
                        TypeStyleRow(
                            style: "Subheadline",
                            font: Typography.subheadline,
                            details: "Arial Regular, 15pt"
                        )
                        
                        TypeStyleRow(
                            style: "Footnote",
                            font: Typography.footnote,
                            details: "Arial Regular, 13pt"
                        )
                        
                        TypeStyleRow(
                            style: "Caption",
                            font: Typography.caption1,
                            details: "Arial Regular, 12pt"
                        )
                    }
                }
                .padding(Spacing.screenPadding)
            }
        }
        .navigationTitle("Typography")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TypeStyleRow: View {
    let style: String
    let font: Font
    let details: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxSmall) {
            Text(style)
                .font(Typography.caption1)
                .foregroundColor(ColorTokens.textSecondary)
            
            Text("The quick brown fox jumps")
                .font(font)
                .foregroundColor(ColorTokens.textPrimary)
            
            Text(details)
                .font(Typography.caption2)
                .foregroundColor(ColorTokens.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.small)
        .background(ColorTokens.surface1)
        .cornerRadius(Spacing.cornerRadiusSmall)
    }
}

#Preview {
    NavigationStack {
        TypographyShowcaseView()
    }
}