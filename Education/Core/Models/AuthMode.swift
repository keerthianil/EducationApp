//
//  AuthMode.swift
//  Education
//
//  Created by Keerthi Reddy on 10/28/25.
//
import Foundation

enum AuthMode: String, CaseIterable, CustomStringConvertible {
    case login = "Login"
    case register = "Register"
    var description: String { rawValue }
}
