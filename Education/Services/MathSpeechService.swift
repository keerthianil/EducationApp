//
//  MathSpeechService.swift
//  Education
//
//  Created by Keerthi Reddy on 10/28/25.
//

import Foundation
import Combine

final class MathSpeechService: ObservableObject {
    enum Verbosity { case brief, verbose }

    // Very small placeholder: converts a tiny LaTeX subset to speakable text, Replace with a proper MathML/LaTeX parser when ready
    
    func speakable(from latex: String, verbosity: Verbosity) -> String {
        var t = latex
        t = t.replacingOccurrences(of: "\\frac{", with: "fraction of ")
        t = t.replacingOccurrences(of: "}{", with: " over ")
        t = t.replacingOccurrences(of: "}", with: "")
        t = t.replacingOccurrences(of: "\\sqrt", with: "square root of ")
        t = t.replacingOccurrences(of: "^", with: " to the power of ")
        t = t.replacingOccurrences(of: "_", with: " sub ")
        t = t.replacingOccurrences(of: "\\cdot", with: " times ")

        switch verbosity {
        case .brief:   return t
        case .verbose: return "Start equation. \(t). End equation."
        }
    }
}
