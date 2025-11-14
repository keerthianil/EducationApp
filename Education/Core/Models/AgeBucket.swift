//
//  AgeBucket.swift
//  Education
//
//  Created by Keerthi Reddy on 10/28/25.
//
import Foundation

enum AgeBucket: String, CaseIterable, Identifiable, Codable, CustomStringConvertible {
    case middleSchool = "8–12 • Middle School"
    case highSchool   = "12–18 • High School"
    case adult        = "18–45 • Adult"
    case veteran      = "45+ • Veteran"

    var id: String { rawValue }
    var description: String { rawValue }
}
