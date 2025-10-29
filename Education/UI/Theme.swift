//
//  Theme.swift
//  Education
//
//  Created by Keerthi Reddy on 10/28/25.
//
import SwiftUI

enum Theme {
    enum Spacing {
        static let xs: CGFloat = 8, sm: CGFloat = 12, md: CGFloat = 16, lg: CGFloat = 24, xl: CGFloat = 32
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(Color.accentColor.opacity(configuration.isPressed ? 0.7 : 1))
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
    }
}
