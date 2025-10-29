//
//  LoginViewModel.swift
//  Education
//
//  Created by Keerthi Reddy on 10/28/25.
//

import Foundation
import Combine

final class LoginViewModel: ObservableObject {
    @Published var mode: AuthMode = .login
    @Published var email: String = ""
    @Published var password: String = ""

    var isFormValid: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !password.isEmpty
    }
}
