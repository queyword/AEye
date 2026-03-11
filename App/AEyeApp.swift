import SwiftUI

@main
struct AEyeApp: App {
    private let showAboutOnLaunch = ProcessInfo.processInfo.arguments.contains("-showAbout")

    var body: some Scene {
        WindowGroup {
            EyeView(showAboutOnLaunch: showAboutOnLaunch)
                .preferredColorScheme(.dark)
        }
    }
}
