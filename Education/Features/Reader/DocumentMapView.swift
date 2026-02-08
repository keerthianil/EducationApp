//
//  DocumentMapView.swift
//  Education
//
//  Created by Keerthi Reddy on 11/7/25.
//

import SwiftUI

struct DocumentMapView: View {
    let json: String
    let title: String?
    let summaries: [String]?

    private var accessibilityDescription: String {
        var desc = title ?? "Map"
        if let summaries, !summaries.isEmpty {
            desc += ". " + summaries.joined(separator: ". ")
        }
        return desc
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let t = title {
                Text(t)
                    .font(.custom("Arial", size: 17).weight(.bold))
                    .foregroundColor(Color(hex: "#121417"))
                    .accessibilityHidden(true)
            }

            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: "#DEECF8"))
                .frame(height: 220)
                .overlay(
                    VStack(spacing: 6) {
                        Text("✅ mapNode rendered")
                            .font(.custom("Arial", size: 16).weight(.bold))
                            .foregroundColor(Color(hex: "#121417"))
                        Text("JSON length: \(json.count)")
                            .font(.custom("Arial", size: 14))
                            .foregroundColor(Color(hex: "#121417"))
                    }
                )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityAddTraits(.isImage)
    }
}
