import Foundation
import Combine

// MARK: - Request Priority
// This enum is created to solve the filter delay problem by giving different priorities to different types of requests
enum RequestPriority {
    case high      // User-initiated (filter changes, immediate needs)
    case normal    // Regular app functionality (coin list loading, etc.)
    case low       // Background operations, auto-refresh - These can wait
    
    var delayInterval: TimeInterval {
        switch self {
        case .high:   return 1.0  // Allow faster user interactions  
        case .normal: return 3.0  // Moderate rate limiting for regular requests
        case .low:    return 6.0  // Conservative rate limiting for background requests
        }
    }
    
    var description: String {
        switch self {
        case .high:   return "🔴 HIGH"
        case .normal: return "🟡 NORMAL"
        case .low:    return "🔵 LOW"
        }
    }
}

// MARK: - Request Manager
final class RequestManager: RequestManagerProtocol {
    static let shared = RequestManager()
    
    private var activeRequests: [String: AnyPublisher<Any, Error>] = [:]
    private let queue = DispatchQueue(label: "request.manager.queue", qos: .utility)
    private var cancellables = Set<AnyCancellable>()
    
    // Priority-based rate limiting
    private var lastRequestTimes: [String: Date] = [:]
    private var coinGeckoRequestCount: Int = 0
    private var coinGeckoWindowStart: Date = Date()
    private let coinGeckoMaxRequests: Int = 45               // More reasonable limit for user interactions
    private let coinGeckoWindowDuration: TimeInterval = 60.0 // 1 minute window
    
    // Rate limit cooldown management
    private var isInCooldownMode: Bool = false
    private var cooldownEndTime: Date = Date()
    private let baseCooldownDuration: TimeInterval = 15.0    // Reduced to 15 seconds base cooldown
    private let maxCooldownDuration: TimeInterval = 120.0    // Reduced to 2 minutes max cooldown
    private var consecutiveRateLimits: Int = 0
    private var lastRateLimitTime: Date = Date.distantPast   // Track timing between rate limits
    
    // Exponential backoff for rate limiting
    private var retryAttempts: [String: Int] = [:]           // Track retry attempts per request
    private let maxRetryAttempts: Int = 2                    // Reduced retry attempts to respect rate limits
    private let baseRetryDelay: TimeInterval = 5.0          // Balanced retry delay
    private let maxRetryDelay: TimeInterval = 60.0          // Reasonable max retry delay
    
    // Priority queue system
    // Separated requests into different queues so high priority requests jump the line
    private var highPriorityQueue: [() -> Void] = []        // Filter changes will be processed first
    private var normalPriorityQueue: [() -> Void] = []      // Regular requests
    private var lowPriorityQueue: [() -> Void] = []         // Background operations get processed last
    private var isProcessingQueue = false
    
    /**
     * DEPENDENCY INJECTION INITIALIZER
     * 
     * Internal access allows for:
     * - Testing with fresh instances
     * - Dependency injection in tests  
     * - Production singleton pattern
     */
    init() {}
    
    // MARK: - Rate Limit Cooldown Management
    
    /**
     * CHECK IF WE'RE IN COOLDOWN MODE
     * 
     * After hitting multiple 429 errors, we enter cooldown mode to respect
     * CoinGecko's rate limits and prevent further API abuse.
     */
    private func isInRateLimitCooldown() -> Bool {
        let now = Date()
        if isInCooldownMode && now < cooldownEndTime {
            let remainingTime = cooldownEndTime.timeIntervalSince(now)
            print("❄️ Rate limit cooldown active: \(Int(remainingTime))s remaining")
            return true
        } else if isInCooldownMode && now >= cooldownEndTime {
            // Cooldown period ended
            isInCooldownMode = false
            consecutiveRateLimits = 0
            print("🌟 Rate limit cooldown ended - resuming normal operations")
        }
        return false
    }
    
    /**
     * ENTER COOLDOWN MODE AFTER RATE LIMIT
     * 
     * Implements smart progressive backoff based on rate limit patterns:
     * - Quick consecutive hits = longer cooldown
     * - Spaced out hits = shorter cooldown
     * - First hit = minimal cooldown
     */
    private func enterRateLimitCooldown() {
        let now = Date()
        let timeSinceLastRateLimit = now.timeIntervalSince(lastRateLimitTime)
        
        // If rate limits are happening quickly (< 60s apart), be more aggressive
        if timeSinceLastRateLimit < 60.0 && consecutiveRateLimits > 0 {
            consecutiveRateLimits += 1
            print("🚨 Rapid rate limits detected - increasing cooldown severity")
        } else {
            // Reset consecutive count if rate limits are spaced out
            consecutiveRateLimits = 1
            print("⏱️ Spaced rate limit - using moderate cooldown")
        }
        
        lastRateLimitTime = now
        
        // Smart cooldown calculation
        let cooldownMultiplier = consecutiveRateLimits == 1 ? 1.0 : Double(consecutiveRateLimits)
        let cooldownDuration = min(baseCooldownDuration * cooldownMultiplier, maxCooldownDuration)
        
        isInCooldownMode = true
        cooldownEndTime = now.addingTimeInterval(cooldownDuration)
        
        print("❄️ Smart cooldown: \(Int(cooldownDuration))s (severity level: \(consecutiveRateLimits))")
    }
    
    // MARK: - Test Support
    
    /**
     * RESET ALL STATE FOR TESTING
     * 
     * Clears all internal state to ensure test isolation.
     * Should only be called from test code.
     */
    func resetForTesting() {
        queue.sync(flags: .barrier) {
            // Clear request tracking
            activeRequests.removeAll()
            lastRequestTimes.removeAll()
            retryAttempts.removeAll()
            
            // Reset rate limiting
            coinGeckoRequestCount = 0
            coinGeckoWindowStart = Date()
            
            // Clear priority queues
            highPriorityQueue.removeAll()
            normalPriorityQueue.removeAll()
            lowPriorityQueue.removeAll()
            isProcessingQueue = false
            
            // Cancel all active subscriptions
            cancellables.removeAll()
        }
    }
    
    // MARK: - Generic Request Deduplication with Priority
    // Core function
    // Deduplicates by checking activeRequests and applies throttling using lastRequestTimes
    // Removes completed request from map
    // Uses combine's future + .sink to deliver results
    func executeRequest<T>(
        key: String,
        priority: RequestPriority = .normal,
        request: @escaping () -> AnyPublisher<T, Error>
    ) -> AnyPublisher<T, Error> {
        
        return Future<T, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(RequestError.castingError))
                promise(.failure(RequestError.castingError))
                return
            }
            
            self.queue.async(flags: .barrier) {
                // Check if we should throttle this request based on priority
                // This checks how recently the same reuquest was made using 'key'
                if let lastTime = self.lastRequestTimes[key], // Thread-safe write
                   Date().timeIntervalSince(lastTime) < priority.delayInterval {
                    
                    // For HIGH priority request, reduce throttling significantly - only block if less than 1 second apart
                    // If it's too soon based on priority, it blocks the request (avoids API spam).
                    if priority == .high {
                        let timeSinceLastRequest = Date().timeIntervalSince(lastTime)
                        if timeSinceLastRequest < 1.0 { // Only throttle if less than 1 second
                            promise(.failure(RequestError.throttled))
                            return
                        }
                    } else {
                        // Normal/low priority requests still get full throttling
                        promise(.failure(RequestError.throttled))
                        return
                    }
                }
                
                // This checks if request is already running -> this prevents duplicate API calls
                if let existingRequest = self.activeRequests[key] {
                    print("♻️ \(priority.description) request deduplication: \(key)")
                    // Return the existing request, cast to the correct type
                    existingRequest
                        .tryMap { result in
                            guard let typedResult = result as? T else {
                                throw RequestError.castingError
                            }
                            return typedResult
                        }
                        .sink(
                            receiveCompletion: { completion in
                                switch completion {
                                case .finished:
                                    break
                                case .failure(let error):
                                    promise(.failure(error))
                                }
                            },
                            receiveValue: { value in
                                promise(.success(value))
                            }
                        )
                        .store(in: &self.cancellables)
                    return
                }
                
                // Actually starts new request with logging (for debugging purposes)
                let publisher = request()
                    .handleEvents(
                        receiveSubscription: { _ in
                            print("🚀 \(priority.description) request started: \(key)")
                        },
                        
                        // After we get a response, update lastRequestTimes so throttling can work next time.
                        receiveOutput: { [weak self] _ in
                            self?.queue.async(flags: .barrier) {
                                self?.lastRequestTimes[key] = Date()
                            }
                        },
                        
                        // Removes the finished request from activeRequests to free up memory and avoid stale reuse.
                        receiveCompletion: { [weak self] completion in
                            switch completion {
                            case .finished:
                                print("✅ \(priority.description) request completed: \(key)")
                            case .failure(let error):
                                print("❌ \(priority.description) request failed: \(key) - \(error)")
                            }
                            self?.queue.async(flags: .barrier) {
                                self?.activeRequests.removeValue(forKey: key)
                            }
                        }
                    )
                    .map { $0 as Any }
                    .eraseToAnyPublisher()
                
                // Before it runs, it's saved in activeRequests so future calls with same key can reuse it.
                // Stores the request basically
                self.activeRequests[key] = publisher
                
                // Execute the request
                // This sends the result back to the caller, whether it succeeded or failed.
                publisher
                    .tryMap { result in
                        guard let typedResult = result as? T else {
                            throw RequestError.castingError
                        }
                        return typedResult
                    }
                    .sink(
                        receiveCompletion: { completion in
                            switch completion {
                            case .finished:
                                break
                            case .failure(let error):
                                promise(.failure(error))
                            }
                        },
                        receiveValue: { value in
                            promise(.success(value))
                        }
                    )
                    .store(in: &self.cancellables)
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Specific Request Methods
    // These are wrapper methods for specific requests that:
    // Generates a unique key and calls executeRequest with a custom closure
    // Ensures all requests go through the manager
    
    func fetchTopCoins(
        limit: Int,
        convert: String,
        start: Int,
        sortType: String = "market_cap",
        sortDir: String = "desc",
        priority: RequestPriority = .normal,
        apiCall: @escaping () -> AnyPublisher<[Coin], NetworkError>
    ) -> AnyPublisher<[Coin], Error> {
        let key = "top_coins_\(limit)_\(start)_\(convert)_\(sortType)_\(sortDir)"
        
        return executeRequest(key: key, priority: priority) {
            apiCall()
                .map { $0 as [Coin] }
                .mapError { $0 as Error }
                .eraseToAnyPublisher()
        }
    }
    
    func fetchCoinLogos(
        ids: [Int],
        priority: RequestPriority = .low, // Logos default to low priority - they're not urgent
        apiCall: @escaping () -> AnyPublisher<[Int: String], Never>
    ) -> AnyPublisher<[Int: String], Error> {
        let key = "logos_\(ids.sorted().map(String.init).joined(separator: "_"))"
        
        return executeRequest(key: key, priority: priority) {
            apiCall()
                .map { $0 as [Int: String] }
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
    }
    
    func fetchQuotes(
        ids: [Int],
        convert: String,
        priority: RequestPriority = .normal,
        apiCall: @escaping () -> AnyPublisher<[Int: Quote], NetworkError>
    ) -> AnyPublisher<[Int: Quote], Error> {
        let key = "quotes_\(ids.sorted().map(String.init).joined(separator: "_"))_\(convert)"
        
        return executeRequest(key: key, priority: priority) {
            apiCall()
                .map { $0 as [Int: Quote] }
                .mapError { $0 as Error }
                .eraseToAnyPublisher()
        }
    }
    
    // Due to CoinGecko's restrictions:
    // This method tracks requests in a 60-second window -> Capped to 7 requests/minute
    // If the cap is reached → returns .rateLimited error
    // Adds each chart request to a priority queue
    // Queues are processed in order (high > normal > low), and each item is spaced out by its delay.

    func fetchOHLCData(
        coinId: String,
        currency: String,
        days: String,
        priority: RequestPriority = .normal,
        apiCall: @escaping () -> AnyPublisher<[OHLCData], NetworkError>
    ) -> AnyPublisher<[OHLCData], Error> {
        
        let key = "ohlc_\(coinId)_\(currency)_\(days)"
        
        return Future<[OHLCData], Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(RequestError.castingError))
                return
            }
            
            self.queue.async {
                // Check if we're in cooldown mode first
                if self.isInRateLimitCooldown() {
                    promise(.failure(RequestError.rateLimited))
                    return
                }
                
                // Check CoinGecko rate limit window
                let now = Date()
                if now.timeIntervalSince(self.coinGeckoWindowStart) >= self.coinGeckoWindowDuration {
                    // Reset window
                    self.coinGeckoWindowStart = now
                    self.coinGeckoRequestCount = 0
                    print("🔄 CoinGecko rate limit window reset for OHLC")
                }
                
                // Check if we're approaching rate limit
                if self.coinGeckoRequestCount >= self.coinGeckoMaxRequests {
                    print("⚠️ CoinGecko OHLC rate limit protection: \(self.coinGeckoRequestCount)/\(self.coinGeckoMaxRequests) requests in current window")
                    promise(.failure(RequestError.rateLimited))
                    return
                }
                
                print("📊 \(priority.description) CoinGecko OHLC request attempt \(self.coinGeckoRequestCount + 1)/\(self.coinGeckoMaxRequests) in current window")
                
                // Add request to appropriate priority queue
                let requestAction = {
                    self.executeWithRetry(key: key, priority: priority) {
                        self.executeRequest(key: key, priority: priority) {
                            apiCall()
                                .handleEvents(receiveOutput: { _ in
                                    // Only increment counter on successful requests
                                    self.queue.async {
                                        self.coinGeckoRequestCount += 1
                                        print("✅ CoinGecko OHLC request successful - counter now: \(self.coinGeckoRequestCount)/\(self.coinGeckoMaxRequests)")
                                    }
                                })
                                .map { $0 as [OHLCData] }
                                .mapError { $0 as Error }
                                .eraseToAnyPublisher()
                        }
                    }
                    .sink(
                        receiveCompletion: { completion in
                            switch completion {
                            case .finished:
                                break
                            case .failure(let error):
                                promise(.failure(error))
                            }
                        },
                        receiveValue: { data in
                            promise(.success(data))
                        }
                    )
                    .store(in: &self.cancellables)
                }
                
                // Add to appropriate queue based on priority
                switch priority {
                case .high:
                    self.highPriorityQueue.append(requestAction) // Filter changes
                case .normal:
                    self.normalPriorityQueue.append(requestAction)
                case .low:
                    self.lowPriorityQueue.append(requestAction) // Background operations
                }
                
                // Process queue if not already processing
                if !self.isProcessingQueue {
                    self.processPriorityQueue()
                }
            }
        }
        .eraseToAnyPublisher()
    }

    func fetchChartData(
        coinId: String,
        currency: String,
        days: String,
        priority: RequestPriority = .normal,
        apiCall: @escaping () -> AnyPublisher<[Double], NetworkError>
    ) -> AnyPublisher<[Double], Error> {
        let key = "chart_\(coinId)_\(currency)_\(days)"
        
        return Future<[Double], Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(RequestError.castingError))
                return
            }
            
            self.queue.async {
                // Check if we're in cooldown mode first
                if self.isInRateLimitCooldown() {
                    promise(.failure(RequestError.rateLimited))
                    return
                }
                
                // Check CoinGecko rate limit window
                let now = Date()
                if now.timeIntervalSince(self.coinGeckoWindowStart) >= self.coinGeckoWindowDuration {
                    // Reset window
                    self.coinGeckoWindowStart = now
                    self.coinGeckoRequestCount = 0
                    print("🔄 CoinGecko rate limit window reset")
                }
                
                // Check if we're approaching rate limit
                if self.coinGeckoRequestCount >= self.coinGeckoMaxRequests {
                    print("⚠️ CoinGecko rate limit protection: \(self.coinGeckoRequestCount)/\(self.coinGeckoMaxRequests) requests in current window")
                    promise(.failure(RequestError.rateLimited))
                    return
                }
                
                print("📊 \(priority.description) CoinGecko request attempt \(self.coinGeckoRequestCount + 1)/\(self.coinGeckoMaxRequests) in current window")
                
                // Add request to appropriate priority queue
                // High priority requests (filter changes) go to the front of the line
                let requestAction = {
                    self.executeWithRetry(key: key, priority: priority) {
                        self.executeRequest(key: key, priority: priority) {
                            apiCall()
                                .handleEvents(receiveOutput: { _ in
                                    // Only increment counter on successful requests
                                    self.queue.async {
                                        self.coinGeckoRequestCount += 1
                                        print("✅ CoinGecko request successful - counter now: \(self.coinGeckoRequestCount)/\(self.coinGeckoMaxRequests)")
                                    }
                                })
                                .map { $0 as [Double] }
                                .mapError { $0 as Error }
                                .eraseToAnyPublisher()
                        }
                    }
                    .sink(
                        receiveCompletion: { completion in
                            switch completion {
                            case .finished:
                                break
                            case .failure(let error):
                                promise(.failure(error))
                            }
                        },
                        receiveValue: { data in
                            promise(.success(data))
                        }
                    )
                    .store(in: &self.cancellables)
                }
                
                // Add to appropriate queue based on priority
                switch priority {
                case .high:
                    self.highPriorityQueue.append(requestAction) // Filter changes
                case .normal:
                    self.normalPriorityQueue.append(requestAction)
                case .low:
                    self.lowPriorityQueue.append(requestAction) // Background operations
                }
                
                // Process queue if not already processing
                if !self.isProcessingQueue {
                    self.processPriorityQueue()
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    // Process high priority requests first
    // Called when a request is added to a queue
    // Picks a request from the highest non-empty queue
    // Waits (DispatchQueue.asyncAfter) based on its priority delay
    // Then runs next item 
    private func processPriorityQueue() {
        isProcessingQueue = true
        
        // Process high priority requests first
        if !highPriorityQueue.isEmpty {
            let nextRequest = highPriorityQueue.removeFirst()
            nextRequest()
            
            // Schedule next with high priority interval (only 2 seconds)
            DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + RequestPriority.high.delayInterval) { [weak self] in
                self?.queue.async {
                    self?.processPriorityQueue()
                }
            }
            return
        }
        
        // Process normal priority requests
        if !normalPriorityQueue.isEmpty {
            let nextRequest = normalPriorityQueue.removeFirst()
            nextRequest()
            
            // Schedule next with normal priority interval (5 seconds)
            DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + RequestPriority.normal.delayInterval) { [weak self] in
                self?.queue.async {
                    self?.processPriorityQueue()
                }
            }
            return
        }
        
        // Process low priority requests last (background stuff waits)
        if !lowPriorityQueue.isEmpty {
            let nextRequest = lowPriorityQueue.removeFirst()
            nextRequest()
            
            // Schedule next with low priority interval (8 seconds - same as before)
            DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + RequestPriority.low.delayInterval) { [weak self] in
                self?.queue.async {
                    self?.processPriorityQueue()
                }
            }
            return
        }
        
        // No requests in queue
        isProcessingQueue = false
    }
    
    // MARK: - Exponential Backoff Methods
    
    private func calculateRetryDelay(for attempt: Int, error: Error? = nil) -> TimeInterval {
        // Special handling for CoinGecko rate limiting (429 errors)
        if let networkError = error as? NetworkError, networkError == .invalidResponse {
            // For rate limiting, use longer delays
            let rateLimitDelay = 15.0 * pow(2.0, Double(attempt)) // 15s, 30s, 60s
            return min(rateLimitDelay, 60.0)
        }
        
        // Standard exponential backoff for other errors
        let exponentialDelay = baseRetryDelay * pow(2.0, Double(attempt))
        return min(exponentialDelay, maxRetryDelay)
    }
    
    private func executeWithRetry<T>(
        key: String,
        priority: RequestPriority,
        request: @escaping () -> AnyPublisher<T, Error>
    ) -> AnyPublisher<T, Error> {
        return request()
            .catch { [weak self] error -> AnyPublisher<T, Error> in
                guard let self = self else {
                    return Fail(error: error).eraseToAnyPublisher()
                }
                
                // Check if this is a rate limiting error that should be retried
                if self.shouldRetryForError(error) {
                    let currentAttempt = self.retryAttempts[key] ?? 0
                    
                    if currentAttempt < self.maxRetryAttempts {
                        let retryDelay = self.calculateRetryDelay(for: currentAttempt, error: error)
                        
                        print("🔄 Retry attempt \(currentAttempt + 1)/\(self.maxRetryAttempts) for \(key) in \(String(format: "%.1f", retryDelay))s")
                        
                        // Update retry count
                        self.queue.async(flags: .barrier) {
                            self.retryAttempts[key] = currentAttempt + 1
                        }
                        
                        return Just(())
                            .delay(for: .seconds(retryDelay), scheduler: DispatchQueue.global())
                            .flatMap { _ in
                                self.executeWithRetry(key: key, priority: priority, request: request)
                            }
                            .eraseToAnyPublisher()
                    } else {
                        print("❌ Max retry attempts reached for \(key)")
                        // Clean up retry count
                        self.queue.async(flags: .barrier) {
                            self.retryAttempts.removeValue(forKey: key)
                        }
                    }
                }
                
                return Fail(error: error).eraseToAnyPublisher()
            }
            .handleEvents(
                receiveOutput: { [weak self] _ in
                    // Clear retry count on success
                    self?.queue.async(flags: .barrier) {
                        self?.retryAttempts.removeValue(forKey: key)
                    }
                }
            )
            .eraseToAnyPublisher()
    }
    
    private func shouldRetryForError(_ error: Error) -> Bool {
        // Retry for rate limiting and invalid response errors
        if let requestError = error as? RequestError {
            return requestError == .rateLimited
        }
        
        if let networkError = error as? NetworkError {
            // Handle 429 rate limit errors with cooldown
            if networkError == .invalidResponse {
                queue.async {
                    // Extend the current window by 30 seconds to space out requests more
                    self.coinGeckoWindowStart = Date().addingTimeInterval(-30)
                    
                    // Enter cooldown mode to prevent further API abuse
                    self.enterRateLimitCooldown()
                    
                    print("⏸️ Extended CoinGecko rate limit window and entered cooldown due to 429 error")
                }
            }
            return networkError == .invalidResponse
        }
        
        return false
    }
    
    // MARK: - Utility Methods
    
    func cancelAllRequests() {
        queue.async {
            self.activeRequests.removeAll()
            self.cancellables.removeAll()
            self.retryAttempts.removeAll() // Clear retry tracking
            // Clear all priority queues when canceling
            self.highPriorityQueue.removeAll()
            self.normalPriorityQueue.removeAll()
            self.lowPriorityQueue.removeAll()
        }
    }
    
    func getActiveRequestsCount() -> Int {
        var count = 0
        queue.sync {
            count = activeRequests.count
        }
        return count
    }
    
    /**
     * GET COOLDOWN STATUS FOR UI FEEDBACK
     * 
     * Returns the remaining cooldown time for user feedback purposes.
     */
    func getCooldownStatus() -> (isInCooldown: Bool, remainingSeconds: Int) {
        let now = Date()
        if isInCooldownMode && now < cooldownEndTime {
            let remainingTime = Int(cooldownEndTime.timeIntervalSince(now))
            return (true, remainingTime)
        }
        return (false, 0)
    }
    
    /**
     * CHECK IF WE SHOULD USE CACHE-FIRST STRATEGY
     * 
     * During cooldowns or when approaching rate limits, prioritize cache over API calls.
     */
    func shouldPreferCache() -> Bool {
        // Always prefer cache during cooldown
        if isInCooldownMode {
            return true
        }
        
        // Prefer cache when we're close to rate limit
        let utilizationRate = Double(coinGeckoRequestCount) / Double(coinGeckoMaxRequests)
        return utilizationRate > 0.8 // Use cache when > 80% of rate limit used
    }
    
    // This method is added to help debug the queue system
    func getQueueStatus() -> (high: Int, normal: Int, low: Int) {
        return queue.sync {
            return (
                high: highPriorityQueue.count,
                normal: normalPriorityQueue.count,
                low: lowPriorityQueue.count
            )
        }
    }
}

// MARK: - Request Error
enum RequestError: Error, Equatable {
    case throttled
    case castingError
    case duplicateRequest
    case rateLimited
    
    var localizedDescription: String {
        switch self {
        case .throttled:
            return "Request throttled to prevent excessive API calls"
        case .castingError:
            return "Failed to cast request result to expected type"
        case .duplicateRequest:
            return "Duplicate request detected"
        case .rateLimited:
            return "Rate limit protection: too many requests per minute"
        }
    }
} 
