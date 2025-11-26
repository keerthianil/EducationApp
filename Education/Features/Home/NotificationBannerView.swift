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
        HStack(spacing: 12) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 24))
                .foregroundColor(ColorTokens.info)
                .frame(width: 48, height: 48)
                .background(Color(hex: "#DEECF8"))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.custom("Arial", size: 17).weight(.bold))
                    .foregroundColor(Color(hex: "#121417"))
                Text(subtitle)
                    .font(.custom("Arial", size: 13))
                    .foregroundColor(Color(hex: "#61758A"))
            }

            Spacer()
            
            // View button - PRIMARY color per Figma (not green!)
            Button("View") { action() }
                .font(.custom("Arial", size: 14).weight(.bold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(ColorTokens.primary) // Teal primary, not green
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(16)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "#DADDE2"), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle).")
        .accessibilityHint("Double tap to open.")
    }
}
