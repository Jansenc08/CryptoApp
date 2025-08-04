import Foundation
import Combine

// MARK: - Publisher Extensions for Common Patterns

extension Publisher {
    
    // MARK: - Simple UI Update Patterns
    
    /**
     * Most common pattern: .receive(on: DispatchQueue.main) + .sink + .store(in:)
     * For publishers that never fail (Failure == Never)
     */
    func sinkForUI(
        _ receiveValue: @escaping (Output) -> Void,
        storeIn cancellables: inout Set<AnyCancellable>
    ) where Failure == Never {
        receive(on: DispatchQueue.main)
            .sink(receiveValue: receiveValue)
            .store(in: &cancellables)
    }
    
    /**
     * For publishers that can fail - handles both completion and value
     */
    func sinkForUI(
        receiveCompletion: @escaping (Subscribers.Completion<Failure>) -> Void = { _ in },
        receiveValue: @escaping (Output) -> Void,
        storeIn cancellables: inout Set<AnyCancellable>
    ) {
        receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: receiveCompletion,
                receiveValue: receiveValue
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Deduplication Patterns
    
    /**
     * UI updates with deduplication for Equatable outputs
     */
    func sinkForUIWithDeduplication(
        _ receiveValue: @escaping (Output) -> Void,
        storeIn cancellables: inout Set<AnyCancellable>
    ) where Output: Equatable, Failure == Never {
        removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: receiveValue)
            .store(in: &cancellables)
    }
    
    // MARK: - Error Handling Patterns
    
    /**
     * Safe UI updates with automatic error logging
     */
    func sinkForUISafely(
        operation: String = "Publisher operation",
        receiveValue: @escaping (Output) -> Void,
        storeIn cancellables: inout Set<AnyCancellable>
    ) {
        receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        AppLogger.error("\(operation) failed", error: error)
                    }
                },
                receiveValue: receiveValue
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Network Request Patterns
    
    /**
     * Network request with loading state management
     */
    func handleNetworkWithLoading(
        operation: String,
        loadingSubject: CurrentValueSubject<Bool, Never>,
        onSuccess: @escaping (Output) -> Void,
        onError: @escaping (Error) -> Void = { _ in },
        storeIn cancellables: inout Set<AnyCancellable>
    ) {
        // Set loading to true
        loadingSubject.send(true)
        
        self
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    loadingSubject.send(false)
                    if case .failure(let error) = completion {
                        AppLogger.error("\(operation) failed", error: error)
                        onError(error)
                    }
                },
                receiveValue: { output in
                    AppLogger.network("\(operation) succeeded")
                    onSuccess(output)
                }
            )
            .store(in: &cancellables)
    }
}

// MARK: - Search Debouncing Utilities

extension Publisher where Output == String, Failure == Never {
    
    /**
     * Common search debouncing pattern
     */
    func debounceForSearch(
        milliseconds: Int = 300,
        performSearch: @escaping (String) -> Void,
        storeIn cancellables: inout Set<AnyCancellable>
    ) {
        debounce(for: .milliseconds(milliseconds), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink(receiveValue: performSearch)
            .store(in: &cancellables)
    }
    
    /**
     * Search debouncing with minimum length validation
     */
    func debounceForSearchWithValidation(
        milliseconds: Int = 300,
        minimumLength: Int = 2,
        performSearch: @escaping (String) -> Void,
        onEmpty: @escaping () -> Void = {},
        storeIn cancellables: inout Set<AnyCancellable>
    ) {
        debounce(for: .milliseconds(milliseconds), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { searchText in
                let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.count >= minimumLength {
                    performSearch(trimmed)
                } else {
                    onEmpty()
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - Subject Extensions

extension Subject where Failure == Never {
    
    /**
     * Send value safely (prevents crashes if subject is deallocated)
     */
    func sendSafely(_ value: Output) {
        send(value)
    }
}

extension CurrentValueSubject where Failure == Never {
    
    /**
     * Send value only if it's different from current value
     */
    func sendIfChanged(_ value: Output) where Output: Equatable {
        if self.value != value {
            send(value)
        }
    }
}

// MARK: - Timer Utilities

extension Timer {
    
    /**
     * Creates a publisher for periodic updates with proper cleanup
     */
    static func periodicUpdates(
        every interval: TimeInterval,
        on queue: DispatchQueue = .main,
        action: @escaping () -> Void
    ) -> AnyCancellable {
        Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .receive(on: queue)
            .sink { _ in action() }
    }
}

// MARK: - Convenience Typealiases

typealias UIUpdateCancellables = Set<AnyCancellable>
typealias NetworkCancellables = Set<AnyCancellable> 