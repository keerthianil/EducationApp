//
//  AppState.swift 
//  Education
//
//  Created by Keerthi Reddy on 10/28/25.
//

import Foundation
import Combine
final class AppState: ObservableObject {
    enum Route: Hashable { case about, login, profileName, profileAge, tutorial, home }
    @Published var route: Route = .about
    @Published var name: String = ""
    @Published var age: AgeBucket? = nil 
}
