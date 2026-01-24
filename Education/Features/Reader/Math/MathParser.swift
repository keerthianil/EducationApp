//
//  MathParser.swift
//  Education
//
//  Generates spoken text using MathSpeechService
//  The actual conversion logic is in MathSpeechService
//

import Foundation

// NOTE: MathPart and MathNavigationLevel are defined in MathAccessibilityElement.swift

class MathParser {
    
    /// Parse a math expression - returns parts for compatibility
    static func parse(mathml: String?, latex: String?) -> [MathPart] {
        // Return single part - navigation not needed for simplified version
        return [MathPart(text: "equation", level: .term)]
    }
    
    /// Generate full spoken text for the equation using MathSpeechService
    static func fullSpokenText(mathml: String?, latex: String?, mathSpeech: MathSpeechService) -> String {
        let result = mathSpeech.speakable(from: mathml, latex: latex, verbosity: .verbose)
        print("MathParser: Generated spoken text: '\(result)'")
        return result
    }
}
