//
//  ProfileViewModel.swift
//  Education
//
//  Created by Keerthi Reddy on 10/28/25.
//
import Foundation
import Combine

final class ProfileViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var selectedAge: AgeBucket? = .highSchool

    var canContinueFromName: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var canContinueFromAge: Bool {
        selectedAge != nil
    }
}
