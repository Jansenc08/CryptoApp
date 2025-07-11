import Foundation
import Combine

// MARK: - Request Manager
final class RequestManager {
    static let shared = RequestManager()
    
    private var activeRequests: [String: AnyPublisher<Any, Error>] = [:]
    private let queue = DispatchQueue(label: "request.manager.queue", attributes: .concurrent)
    private var cancellables = Set<AnyCancellable>()
    
    // Throttling
    private var lastRequestTimes: [String: Date] = [:]
    private let minimumInterval: TimeInterval = 1.0 // Minimum 1 second between same requests
    
    private init() {}
    
    // MARK: - Generic Request Deduplication
    
    func executeRequest<T>(
        key: String,
        request: @escaping () -> AnyPublisher<T, Error>
    ) -> AnyPublisher<T, Error> {
        
        return queue.sync {
            // Check if we should throttle this request
            if let lastTime = lastRequestTimes[key],
               Date().timeIntervalSince(lastTime) < minimumInterval {
                return Fail(error: RequestError.throttled)
                    .eraseToAnyPublisher()
            }
            
            // Check if request is already in progress
            if let existingRequest = activeRequests[key] {
                // Return the existing request, cast to the correct type
                return existingRequest
                    .tryMap { result in
                        guard let typedResult = result as? T else {
                            throw RequestError.castingError
                        }
                        return typedResult
                    }
                    .eraseToAnyPublisher()
            }
            
            // Create new request
            let publisher = request()
                .handleEvents(
                    receiveOutput: { [weak self] _ in
                        self?.queue.async(flags: .barrier) {
                            self?.lastRequestTimes[key] = Date()
                        }
                    },
                    receiveCompletion: { [weak self] _ in
                        self?.queue.async(flags: .barrier) {
                            self?.activeRequests.removeValue(forKey: key)
                        }
                    }
                )
                .map { $0 as Any }
                .eraseToAnyPublisher()
            
            // Store the request
            activeRequests[key] = publisher
            
            // Return typed publisher
            return publisher
                .tryMap { result in
                    guard let typedResult = result as? T else {
                        throw RequestError.castingError
                    }
                    return typedResult
                }
                .eraseToAnyPublisher()
        }
    }
    
    // MARK: - Specific Request Methods
    
    func fetchTopCoins(
        limit: Int,
        convert: String,
        start: Int,
        apiCall: @escaping () -> AnyPublisher<[Coin], NetworkError>
    ) -> AnyPublisher<[Coin], Error> {
        let key = "top_coins_\(limit)_\(start)_\(convert)"
        
        return executeRequest(key: key) {
            apiCall()
                .map { $0 as [Coin] }
                .mapError { $0 as Error }
                .eraseToAnyPublisher()
        }
    }
    
    func fetchCoinLogos(
        ids: [Int],
        apiCall: @escaping () -> AnyPublisher<[Int: String], Never>
    ) -> AnyPublisher<[Int: String], Error> {
        let key = "logos_\(ids.sorted().map(String.init).joined(separator: "_"))"
        
        return executeRequest(key: key) {
            apiCall()
                .map { $0 as [Int: String] }
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
    }
    
    func fetchQuotes(
        ids: [Int],
        convert: String,
        apiCall: @escaping () -> AnyPublisher<[Int: Quote], NetworkError>
    ) -> AnyPublisher<[Int: Quote], Error> {
        let key = "quotes_\(ids.sorted().map(String.init).joined(separator: "_"))_\(convert)"
        
        return executeRequest(key: key) {
            apiCall()
                .map { $0 as [Int: Quote] }
                .mapError { $0 as Error }
                .eraseToAnyPublisher()
        }
    }
    
    func fetchChartData(
        coinId: String,
        currency: String,
        days: String,
        apiCall: @escaping () -> AnyPublisher<[Double], NetworkError>
    ) -> AnyPublisher<[Double], Error> {
        let key = "chart_\(coinId)_\(currency)_\(days)"
        
        return executeRequest(key: key) {
            apiCall()
                .map { $0 as [Double] }
                .mapError { $0 as Error }
                .eraseToAnyPublisher()
        }
    }
    
    // MARK: - Utility Methods
    
    func cancelAllRequests() {
        queue.async(flags: .barrier) {
            self.activeRequests.removeAll()
            self.cancellables.removeAll()
        }
    }
    
    func getActiveRequestsCount() -> Int {
        return queue.sync {
            return activeRequests.count
        }
    }
}

// MARK: - Request Error
enum RequestError: Error {
    case throttled
    case castingError
    case duplicateRequest
    
    var localizedDescription: String {
        switch self {
        case .throttled:
            return "Request throttled to prevent excessive API calls"
        case .castingError:
            return "Failed to cast request result to expected type"
        case .duplicateRequest:
            return "Duplicate request detected"
        }
    }
} 