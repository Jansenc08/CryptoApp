import Foundation
import Network
import Combine

/**
 * NetworkConnectivityMonitor
 *
 * Practical network connectivity monitoring that detects REAL network issues.
 * Since NWPathMonitor is unreliable in simulator, I use actual network requests.
 *
 * Features:
 * - Detects real network failures from URLSession errors
 * - Publishes immediate connectivity changes via Combine
 * - Thread-safe singleton pattern via DI container
 * - Works reliably in both simulator and device
 */
final class NetworkConnectivityMonitor: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current connectivity status (start with unknown state)
    @Published private(set) var isConnected: Bool = true
    
    /// Track if initial connectivity test has completed
    private(set) var hasCompletedInitialTest = false
    
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
    
    // Stability tracking to prevent false disconnections
    private var consecutiveFailures = 0
    private var consecutiveSuccesses = 0
    private let requiredFailures = 1  // Immediate response to failures
    private let requiredSuccesses = 1 // Immediate response to successes
    
    // API-aware connectivity tracking (prevents false disconnections)
    private var lastAPISuccessTime: Date?
    private let apiSuccessGracePeriod: TimeInterval = 10.0 // 10 seconds
    
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
    
    /**
     * Report successful API activity to prevent false disconnection reports
     * Call this whenever your app successfully completes an API request
     */
    func reportAPISuccess() {
        DispatchQueue.main.async { [weak self] in
            self?.lastAPISuccessTime = Date()
            AppLogger.network("🌐 NetworkConnectivityMonitor: API success reported - preventing false disconnections")
        }
    }
    
    // MARK: - Private Methods
    
    private func setupMonitoring() {
        // Perform initial connectivity test with completion tracking
        testActualConnectivity(isInitial: true)
        
        // Set up NWPathMonitor for immediate WiFi interface change detection
        monitor.pathUpdateHandler = { [weak self] path in
            AppLogger.network("🔄 NetworkConnectivityMonitor: NWPathMonitor detected interface change - status: \(path.status)")
            
            // Immediate burst testing when network interface changes for fastest possible detection
            DispatchQueue.main.async {
                self?.performBurstConnectivityTest()
            }
        }
        monitor.start(queue: queue)
        
        // Start periodic testing
        startConnectivityTimer()
        
        AppLogger.network("🌐 NetworkConnectivityMonitor: Setup completed with NWPathMonitor + fast periodic testing")
    }
    
    private func startConnectivityTimer() {
        connectivityTimer?.invalidate()
        
        // Super fast intervals for immediate detection:
        // 1 second when disconnected (fast reconnection detection)
        // 5 seconds when connected (reasonable balance)
        let interval: TimeInterval = isConnected ? 5.0 : 1.0
        
        connectivityTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.testActualConnectivity(isInitial: false)
        }
        
        AppLogger.network("🔄 NetworkConnectivityMonitor: Timer restarted - \(interval)s interval for \(isConnected ? "CONNECTED" : "DISCONNECTED") state")
    }
    
    /**
     * Performs rapid burst testing for immediate connectivity detection
     * Used when NWPathMonitor detects interface changes for fastest possible reconnection
     */
    private func performBurstConnectivityTest() {
        AppLogger.network("🚀 NetworkConnectivityMonitor: Starting burst connectivity test...")
        
        // Use the fastest possible endpoints with very short timeouts for initial detection
        let burstTestUrls = [
            "https://google.com/generate_204", // Google's fastest endpoint
            "https://apple.com"                // Apple's CDN is usually fast for iOS
        ]
        
        let group = DispatchGroup()
        var anySuccess = false
        let lock = NSLock()
        
        for urlString in burstTestUrls {
            guard let url = URL(string: urlString) else { continue }
            
            var request = URLRequest(url: url)
            request.timeoutInterval = 1.0 // Very aggressive timeout for burst detection
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            
            group.enter()
            session.dataTask(with: request) { data, response, error in
                lock.lock()
                if error == nil && response != nil {
                    anySuccess = true
                    AppLogger.network("🚀 NetworkConnectivityMonitor: Burst test SUCCESS on \(urlString)")
                }
                lock.unlock()
                group.leave()
            }.resume()
        }
        
        // Process burst test results quickly
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            
            AppLogger.network("🚀 NetworkConnectivityMonitor: Burst test completed - success: \(anySuccess)")
            
            // If we're currently disconnected and burst test succeeded, immediately trigger full parallel test
            if !self.isConnected && anySuccess {
                AppLogger.network("🚀 NetworkConnectivityMonitor: Burst detected reconnection - starting full parallel test")
                self.testConnectivityParallel(isInitial: false)
            } else if self.isConnected && !anySuccess {
                // If we're connected but burst test failed, start regular testing to confirm
                self.testActualConnectivity(isInitial: false)
            }
            // If state matches expectation, no immediate action needed - timer will handle it
        }
        
        // Fallback timeout for burst test
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }
            // If we're still disconnected after burst test timeout, start regular testing
            if !self.isConnected {
                self.testActualConnectivity(isInitial: false)
            }
        }
    }
    
    private func testActualConnectivity(isInitial: Bool = false) {
        // Fast reconnection mode: use parallel testing when disconnected or during initial test
        let shouldUseParallelTesting = !isConnected || isInitial
        
        if shouldUseParallelTesting {
            testConnectivityParallel(isInitial: isInitial)
        } else {
            testConnectivitySingle(isInitial: isInitial)
        }
    }
    
    private func testConnectivityParallel(isInitial: Bool) {
        // Use multiple reliable endpoints with parallel testing for faster reconnection
        let testUrls = [
            "https://google.com/generate_204",  // Fast, reliable
            "https://apple.com",                // Usually fast for iOS devices
            "https://httpbin.org/status/200"    // Backup option
        ]
        
        let group = DispatchGroup()
        var results: [Bool] = []
        let resultsQueue = DispatchQueue(label: "connectivity.results")
        
        // Test multiple endpoints in parallel with relaxed timeouts for reconnection
        let timeoutInterval: TimeInterval = isInitial ? 2.0 : 3.0 // More time during reconnection
        
        for urlString in testUrls {
            guard let url = URL(string: urlString) else { continue }
            
            var request = URLRequest(url: url)
            request.timeoutInterval = timeoutInterval
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            
            group.enter()
            session.dataTask(with: request) { data, response, error in
                let testPassed = error == nil && response != nil
                
                resultsQueue.async {
                    results.append(testPassed)
                    group.leave()
                }
                
                if let error = error {
                    AppLogger.network("🔍 NetworkConnectivityMonitor: Parallel test error (\(urlString)): \(error.localizedDescription)")
                }
            }.resume()
        }
        
        // Process results when all tests complete (or timeout)
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            
            let successCount = results.filter { $0 }.count
            let testPassed = successCount > 0 // Any success indicates connectivity
            
            AppLogger.network("🔍 NetworkConnectivityMonitor: Parallel test results: \(successCount)/\(results.count) successful")
            
            self.processConnectivityResult(testPassed: testPassed, isInitial: isInitial, isParallel: true)
        }
        
        // Add timeout for the entire parallel operation
        DispatchQueue.main.asyncAfter(deadline: .now() + timeoutInterval + 1.0) { [weak self] in
            guard let self = self else { return }
            
            // If we haven't gotten results yet, assume failure
            if results.isEmpty {
                AppLogger.network("🔍 NetworkConnectivityMonitor: Parallel test timed out completely")
                self.processConnectivityResult(testPassed: false, isInitial: isInitial, isParallel: true)
            }
        }
    }
    
    private func testConnectivitySingle(isInitial: Bool) {
        // Single test for when already connected (maintenance mode)
        let testUrls = [
            "https://google.com/generate_204",
            "https://apple.com"
        ]
        
        guard let urlString = testUrls.randomElement(),
              let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 2.0 // Slightly longer for stability
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        session.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                let testPassed = error == nil && response != nil
                
                if let error = error {
                    AppLogger.network("🔍 NetworkConnectivityMonitor: Single test error: \(error.localizedDescription)")
                }
                
                self.processConnectivityResult(testPassed: testPassed, isInitial: isInitial, isParallel: false)
            }
        }.resume()
    }
    
    private func processConnectivityResult(testPassed: Bool, isInitial: Bool, isParallel: Bool) {
        // For initial test, set state immediately without debouncing
        if isInitial {
            if self.isConnected != testPassed {
                self.isConnected = testPassed
                // Restart timer with correct interval for initial state
                self.startConnectivityTimer()
            }
            self.hasCompletedInitialTest = true
            return
        }
        
        // Update counters for stability (non-initial tests)
        if testPassed {
            self.consecutiveSuccesses += 1
            self.consecutiveFailures = 0
        } else {
            self.consecutiveFailures += 1
            self.consecutiveSuccesses = 0
        }
        
        // Determine new connectivity state with debouncing
        var newConnectedState = self.isConnected
        
        if !self.isConnected && self.consecutiveSuccesses >= self.requiredSuccesses {
            // Currently disconnected, but got enough successes -> connected
            newConnectedState = true
        } else if self.isConnected && self.consecutiveFailures >= self.requiredFailures {
            // Currently connected, but got enough failures -> check API success before disconnecting
            if let lastAPITime = self.lastAPISuccessTime,
               Date().timeIntervalSince(lastAPITime) < self.apiSuccessGracePeriod {
                // Recent API success - ignore the disconnection report
                AppLogger.network("🌐 NetworkConnectivityMonitor: Ignoring disconnection due to recent API success (\(Date().timeIntervalSince(lastAPITime).rounded())s ago)")
                // Reset counters to prevent repeated messages
                self.consecutiveFailures = 0
                self.consecutiveSuccesses = 0
                return
            } else {
                // No recent API success - proceed with disconnection
                newConnectedState = false
            }
        }
        
        // Only update if the state actually changed
        if self.isConnected != newConnectedState {
            let previousState = self.isConnected ? "CONNECTED" : "DISCONNECTED" 
            let newState = newConnectedState ? "CONNECTED" : "DISCONNECTED"
            let testType = isParallel ? "parallel" : "single"
            
            AppLogger.network("🌐 NetworkConnectivityMonitor: Network connectivity changed: \(previousState) → \(newState) (via \(testType) test)")
            
            self.isConnected = newConnectedState
            
            // Reset counters after state change
            self.consecutiveFailures = 0
            self.consecutiveSuccesses = 0
            
            // CRITICAL: Restart timer with new interval when connectivity changes
            self.startConnectivityTimer()
            
            // If we just connected, do one more quick parallel test to confirm stability
            if newConnectedState && !isParallel {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.testConnectivityParallel(isInitial: false)
                }
            }
        }
    }
}

// MARK: - Protocol Conformance

extension NetworkConnectivityMonitor: NetworkConnectivityMonitorProtocol {}
