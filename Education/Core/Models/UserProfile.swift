//
//  UserProfile.swift
//  Education
//
//  Created by Keerthi Reddy on 10/28/25.
//

import Foundation
// reserved for later phases (Firebase etc.)
struct UserProfile: Codable {
    var name: String = ""
    var ageBucket: AgeBucket? = nil
}
