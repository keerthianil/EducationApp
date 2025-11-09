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
                Text(filename).font(Typography.body)
                Text(when).font(Typography.caption1).foregroundColor(ColorTokens.textSecondary)
            }
            Spacer()
            Image(systemName: "ellipsis")
                .accessibilityHidden(true)
        }
        .padding(Spacing.small)
        .background(ColorTokens.surface1)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.cornerRadiusSmall))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(filename). \(when).")
    }
}
