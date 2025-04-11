//
//  chatappApp.swift
//  chatapp
//
//  Created by ENZO on 4/9/25.
//

import SwiftUI
import Firebase

@main
struct chatappApp: App {
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
