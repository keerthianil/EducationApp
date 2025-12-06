//
//  DSUploadedFileCard.swift
//  Education
//
//  Design system component for uploaded file cards
//  Created: December 2024
//

import SwiftUI

/// Design system component for uploaded file cards
/// Features a light teal background with rounded corners
public struct DSUploadedFileCard<Content: View>: View {
    let content: Content
    
    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    public var body: some View {
        content
            .padding(Spacing.medium)
            .background(ColorTokens.uploadedFileCardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.cornerRadius)
                    .stroke(ColorTokens.uploadedFileCardBackground, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Spacing.cornerRadius))
    }
}

#if DEBUG
#Preview {
    DSUploadedFileCard {
        HStack(spacing: 12) {
            Image(systemName: "doc.fill")
                .font(.system(size: 24))
                .foregroundColor(ColorTokens.error)
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Sample File.pdf")
                    .font(.custom("Arial", size: 18.6))
                    .foregroundColor(.black)
                
                Text("Just now, 300KB")
                    .font(.custom("Arial", size: 13.5))
                    .foregroundColor(Color(hex: "#91949B"))
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(ColorTokens.success)
        }
    }
    .padding()
}
#endif

