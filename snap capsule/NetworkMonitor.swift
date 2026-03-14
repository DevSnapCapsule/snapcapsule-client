import Foundation
import Network

/// Shared network reachability monitor for the app.
/// Publishes `isConnected` so views can react to connectivity changes.
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    @Published private(set) var isConnected: Bool = true
    
    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "com.snapcapsule.network-monitor")
    
    private init() {
        monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = (path.status == .satisfied)
            }
        }
        monitor.start(queue: queue)
    }
}

