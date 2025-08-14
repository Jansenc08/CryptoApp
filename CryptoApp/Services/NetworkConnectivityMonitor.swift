import Foundation
import Network
import Combine

/**
 * NetworkConnectivityMonitor
 *
 * Practical network connectivity monitoring that detects REAL network issues.
 * Since NWPathMonitor is unreliable in simulator, we use actual network requests.
 * 
 * Features:
 * - Detects real network failures from URLSession errors
 * - Publishes immediate connectivity changes via Combine
 * - Thread-safe singleton pattern via DI container
 * - Works reliably in both simulator and device
 */
final class NetworkConnectivityMonitor: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current connectivity status
    @Published private(set) var isConnected: Bool = false
    
    /// Publisher for connectivity changes
    var connectivityPublisher: AnyPublisher<Bool, Never> {
        $isConnected.removeDuplicates().eraseToAnyPublisher()
    }
    
    // MARK: - Private Properties
    
    private let monitor: NWPathMonitor
    private let queue: DispatchQueue
    private var isMonitoring = false
    
    // For practical connectivity testing
    private var connectivityTimer: Timer?
    private let session = URLSession.shared
    
    // MARK: - Initialization
    
    init() {
        self.monitor = NWPathMonitor()
        self.queue = DispatchQueue(label: "com.cryptoapp.connectivity.monitor", qos: .utility)
        setupMonitoring()
    }
    
    deinit {
        stop()
    }
    
    // MARK: - Public Methods
    
    /**
     * Start monitoring network connectivity
     * Automatically called during initialization
     */
    func start() {
        guard !isMonitoring else { return }
        
        monitor.start(queue: queue)
        isMonitoring = true
        
        AppLogger.network("NetworkConnectivityMonitor started")
    }
    
    /**
     * Stop monitoring network connectivity
     */
    func stop() {
        guard isMonitoring else { return }
        
        monitor.cancel()
        connectivityTimer?.invalidate()
        connectivityTimer = nil
        isMonitoring = false
        
        AppLogger.network("NetworkConnectivityMonitor stopped")
    }
    
    // MARK: - Private Methods
    
    private func setupMonitoring() {
        // Start with actual connectivity test
        testActualConnectivity()
        
        // Set up periodic real connectivity testing every 5 seconds
        connectivityTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.testActualConnectivity()
        }
        
        AppLogger.network("🌐 NetworkConnectivityMonitor: Setup completed with periodic real connectivity testing")
    }
    
    private func testActualConnectivity() {
        // Test with a simple, fast request to a reliable endpoint
        guard let url = URL(string: "https://httpbin.org/status/200") else { return }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 3.0 // Quick timeout
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        AppLogger.network("🔍 NetworkConnectivityMonitor: Testing actual connectivity...")
        
        session.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                let connected = error == nil && response != nil
                
                AppLogger.network("🔍 NetworkConnectivityMonitor: Connectivity test result: \(connected ? "Connected" : "Disconnected")")
                if let error = error {
                    AppLogger.network("🔍 NetworkConnectivityMonitor: Error: \(error.localizedDescription)")
                }
                
                // Only update if the value actually changed
                if self.isConnected != connected {
                    AppLogger.network("🌐 NetworkConnectivityMonitor: Network connectivity changed: \(connected ? "Connected" : "Disconnected")")
                    AppLogger.network("🌐 NetworkConnectivityMonitor: Previous state: \(self.isConnected), New state: \(connected)")
                    self.isConnected = connected
                } else {
                    AppLogger.network("🌐 NetworkConnectivityMonitor: No change detected (still \(connected ? "connected" : "disconnected"))")
                }
            }
        }.resume()
    }
}

// MARK: - Protocol Conformance

extension NetworkConnectivityMonitor: NetworkConnectivityMonitorProtocol {}