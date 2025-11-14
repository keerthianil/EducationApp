//
//  NotificationBannerView.swift
//  Education
//
//  Created by Keerthi Reddy on 11/7/25.
//

import Foundation
import SwiftUI


struct NotificationBannerView: View {
    let title: String
    let subtitle: String
    var action: () -> Void

    var body: some View {
        HStack(spacing: Spacing.small) {
            Image(systemName: "doc.text.fill")
                .foregroundColor(ColorTokens.info)
                .padding(8)
                .background(ColorTokens.surfaceAdaptive2)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Typography.bodyBold).foregroundColor(ColorTokens.textPrimaryAdaptive)
                Text(subtitle).font(Typography.footnote).foregroundColor(ColorTokens.textSecondaryAdaptive)
            }

            Spacer()
            Button("View") { action() }
                .buttonStyle(PrimaryButtonStyle())
                .frame(width: 96)
        }
        .padding(Spacing.medium)
        .background(ColorTokens.surfaceAdaptive)
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.cornerRadius)
                .stroke(ColorTokens.borderAdaptive, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Spacing.cornerRadius))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle).")
        .accessibilityHint("Double tap to open.")
    }
}

