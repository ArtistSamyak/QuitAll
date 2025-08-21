//
//  KillSwitchApp.swift
//  KillSwitch
//
//  Created by Samyak Pawar on 21/08/2025.
//

import SwiftUI

@main
struct KillSwitchApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    if let window = NSApplication.shared.windows.first {
                        window.center() // positions window in the middle of the screen
                    }
                }
                .frame(width: 260, height: 260) // compact, square (260)
            
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize) // fixed size; no resize handle
    }
}
