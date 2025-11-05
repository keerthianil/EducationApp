//
//  SpacingShowcaseView.swift
//  Education
//

import SwiftUI

struct SpacingShowcaseView: View {
    var body: some View {
        ZStack {
            ColorTokens.background
                .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.large) {
                    Text("Spacing Scale")
                        .font(Typography.heading2)
                        .foregroundColor(ColorTokens.textPrimary)
                    
                    VStack(spacing: Spacing.medium) {
                        SpacingRow(name: "XX Small", value: Spacing.xxSmall)
                        SpacingRow(name: "X Small", value: Spacing.xSmall)
                        SpacingRow(name: "Small", value: Spacing.small)
                        SpacingRow(name: "Medium", value: Spacing.medium)
                        SpacingRow(name: "Large", value: Spacing.large)
                        SpacingRow(name: "X Large", value: Spacing.xLarge)
                        SpacingRow(name: "XX Large", value: Spacing.xxLarge)
                    }
                    
                    Divider()
                        .padding(.vertical, Spacing.small)
                    
                    Text("Component Sizes")
                        .font(Typography.heading3)
                        .foregroundColor(ColorTokens.textPrimary)
                    
                    VStack(spacing: Spacing.medium) {
                        SizeRow(name: "Min Touch Target", value: Spacing.minTouchTarget)
                        SizeRow(name: "Button Height", value: Spacing.buttonHeight)
                        SizeRow(name: "Corner Radius", value: Spacing.cornerRadius)
                        SizeRow(name: "Corner Radius Small", value: Spacing.cornerRadiusSmall)
                    }
                }
                .padding(Spacing.screenPadding)
            }
        }
        .navigationTitle("Spacing")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SpacingRow: View {
    let name: String
    let value: CGFloat
    
    var body: some View {
        HStack {
            Text(name)
                .font(Typography.body)
                .foregroundColor(ColorTokens.textPrimary)
            
            Spacer()
            
            Text("\(Int(value))pt")
                .font(Typography.bodyBold)
                .foregroundColor(ColorTokens.textSecondary)
            
            Rectangle()
                .fill(ColorTokens.primary)
                .frame(width: value, height: 20)
                .cornerRadius(2)
        }
        .padding(Spacing.small)
        .background(ColorTokens.surface1)
        .cornerRadius(Spacing.cornerRadiusSmall)
    }
}

struct SizeRow: View {
    let name: String
    let value: CGFloat
    
    var body: some View {
        HStack {
            Text(name)
                .font(Typography.body)
                .foregroundColor(ColorTokens.textPrimary)
            
            Spacer()
            
            Text("\(Int(value))pt")
                .font(Typography.bodyBold)
                .foregroundColor(ColorTokens.primary)
        }
        .padding(Spacing.small)
        .background(ColorTokens.surface1)
        .cornerRadius(Spacing.cornerRadiusSmall)
    }
}

#Preview {
    NavigationStack {
        SpacingShowcaseView()
    }
}