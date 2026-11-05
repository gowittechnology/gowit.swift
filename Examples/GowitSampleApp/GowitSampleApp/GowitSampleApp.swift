import SwiftUI

/// A minimal host for the declarative standard-ad renderer.
///
/// It exists to prove the lifecycle in a simulator, so it deliberately makes **no
/// network call**: the ad it draws is decoded from a bundled fixture. A sample that
/// needed a reachable ad server would prove the server was up, not that the renderer
/// works.
@main
struct GowitSampleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
