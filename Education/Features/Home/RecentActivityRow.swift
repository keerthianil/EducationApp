//
//  RecentActivityRow.swift
//  Education
//
//  Created by Keerthi Reddy on 11/7/25.
//

import Foundation
import SwiftUI

struct RecentActivityRow: View {
    let filename: String
    let when: String

    var body: some View {
        HStack {
            Image(systemName: "doc")
                .foregroundColor(ColorTokens.primary)
            VStack(alignment: .leading) {
                Text(filename).font(Typography.body).foregroundColor(ColorTokens.textPrimaryAdaptive)
                Text(when).font(Typography.caption1).foregroundColor(ColorTokens.textSecondaryAdaptive)
            }
            Spacer()
            Image(systemName: "ellipsis").accessibilityHidden(true)
        }
        .padding(Spacing.small)
        .background(ColorTokens.surfaceAdaptive)
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.cornerRadiusSmall)
                .stroke(ColorTokens.borderAdaptive, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Spacing.cornerRadiusSmall))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(filename). \(when).")
    }
}
