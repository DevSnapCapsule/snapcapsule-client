import SwiftUI
import os.log

@main
struct SnapCapsuleApp: App {
    private let logger = Logger(subsystem: "com.snapcapsule.snap-capsule", category: "App")
    @StateObject private var networkMonitor = NetworkMonitor.shared
    
    init() {
        logger.info("🚀 SnapCapsule app initializing...")
    }
    
    var body: some Scene {
        WindowGroup {
            SplashScreenView()
                .environmentObject(networkMonitor)
        }
    }
} 