import SwiftUI

@main
struct AIAvatarApp: App {
    var body: some Scene {
        Window("AI Avatar", id: "main") {
            if ProcessInfo.processInfo.environment["AI_AVATAR_TESTING"] == "1" {
                Text("AI Avatar Tests")
            } else {
                ContentView()
            }
        }
        .defaultSize(width: 1040, height: 720)
    }
}
