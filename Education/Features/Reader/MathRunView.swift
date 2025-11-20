//
//  MathRunView.swift
//  Education
//
//  Created by Keerthi Reddy on 11/7/25.
//

import Foundation
import SwiftUI

struct MathRunView: View {
    let latex: String?
    let mathml: String?
    @EnvironmentObject var haptics: HapticService
    @EnvironmentObject var mathSpeech: MathSpeechService
    @EnvironmentObject var speech: SpeechService

    var body: some View {
        Button {
            haptics.mathStart()

            let spoken = mathSpeech.speakable(
                from: latex ?? (mathml ?? "equation"),
                verbosity: .brief
            )

            // Ask VoiceOver itself to read the math, so it’s queued,
            // not overlapping with the control’s label.
            UIAccessibility.post(
                notification: .announcement,
                argument: spoken
            )

            haptics.mathEnd()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "function")
                Text("Equation")
            }
            .padding(8)
            .background(ColorTokens.primaryLight3)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .accessibilityLabel("Equation")
        .accessibilityHint("Double tap to hear the equation.")
    }
}
