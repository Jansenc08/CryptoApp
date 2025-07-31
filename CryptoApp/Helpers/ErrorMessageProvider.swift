import Foundation

/**
 * ErrorMessageProvider
 * 
 * Centralized error message generation with context injection.
 * This eliminates duplication across ViewModels while maintaining
 * context-specific messaging capabilities.
 */
final class ErrorMessageProvider {
    
    static let shared = ErrorMessageProvider()
    private init() {}
    
    // MARK: - Context-Aware Error Messages
    
    /**
     * Generate user-friendly error message with context
     * 
     * @param error: The technical error that occurred
     * @param context: Context information for personalized messages
     * @return: User-friendly error message with actionable advice
     */
    func getMessage(for error: Error, context: ErrorContext) -> String {
        // Handle rate limiting errors
        if let requestError = error as? RequestError {
            switch requestError {
            case .rateLimited:
                return getTemporarilyUnavailableMessage(for: context)
            case .throttled:
                return getThrottledMessage(for: context)
            case .duplicateRequest:
                return "Please wait for the current request to complete."
            case .castingError:
                return "There was an issue processing the data. Please try again."
            }
        }
        
        // Handle network errors
        if let networkError = error as? NetworkError {
            switch networkError {
            case .badURL:
                return getNotAvailableMessage(for: context)
            case .invalidResponse:
                return getServiceBusyMessage(for: context)
            case .decodingError:
                return getProcessingErrorMessage(for: context)
            case .unknown:
                return getConnectionErrorMessage()
            }
        }
        
        // Handle connectivity issues
        if (error as NSError).domain == NSURLErrorDomain {
            return "Please check your internet connection and try again."
        }

        // Fallback for unknown errors
        return getGenericErrorMessage(for: context)
    }
    
    /**
     * Generate retry-specific error message with retry action context
     * 
     * @param error: The technical error that occurred
     * @param context: Context information for personalized messages
     * @return: RetryErrorInfo containing message and retry availability
     */
    func getRetryInfo(for error: Error, context: ErrorContext) -> RetryErrorInfo {
        let isRetryable = determineIfRetryable(error: error)
        let message = getRetryMessage(for: error, context: context, isRetryable: isRetryable)
        
        return RetryErrorInfo(
            message: message,
            isRetryable: isRetryable,
            suggestedAction: getSuggestedAction(for: error, context: context)
        )
    }
    
    // MARK: - Retry Logic
    
    private func determineIfRetryable(error: Error) -> Bool {
        // Handle request errors
        if let requestError = error as? RequestError {
            switch requestError {
            case .rateLimited, .throttled:
                return true // Can retry after cooldown
            case .duplicateRequest:
                return false // Should wait for current request
            case .castingError:
                return true // Might be temporary processing issue
            }
        }
        
        // Handle network errors
        if let networkError = error as? NetworkError {
            switch networkError {
            case .badURL:
                return false // URL construction issue, won't resolve with retry
            case .invalidResponse:
                return true // Server might be temporarily busy
            case .decodingError:
                return true // Could be temporary API response issue
            case .unknown:
                return true // Unknown errors might be temporary
            }
        }
        
        // Handle URL errors (connectivity issues)
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return true // Connectivity can be restored
            case .timedOut:
                return true // Server might respond on retry
            case .cannotFindHost, .cannotConnectToHost:
                return true // Network issues might be temporary
            case .badURL, .unsupportedURL:
                return false // URL issues won't resolve with retry
            default:
                return true // Most network errors are potentially temporary
            }
        }
        
        return true // Default to retryable for unknown error types
    }
    
    private func getRetryMessage(for error: Error, context: ErrorContext, isRetryable: Bool) -> String {
        if !isRetryable {
            return getNonRetryableMessage(for: error, context: context)
        }
        
        // Generate retry-specific messages
        if let requestError = error as? RequestError {
            switch requestError {
            case .rateLimited, .throttled:
                return getRetryAfterCooldownMessage(for: context)
            case .castingError:
                return getRetryProcessingMessage(for: context)
            case .duplicateRequest:
                return "Request in progress. Please wait."
            }
        }
        
        if let networkError = error as? NetworkError {
            switch networkError {
            case .invalidResponse:
                return getRetryServerBusyMessage(for: context)
            case .decodingError:
                return getRetryProcessingMessage(for: context)
            case .unknown:
                return getRetryConnectionMessage(for: context)
            case .badURL:
                return getNonRetryableMessage(for: networkError, context: context)
            }
        }
        
        if (error as NSError).domain == NSURLErrorDomain {
            return getRetryConnectionMessage(for: context)
        }
        
        return getRetryGenericMessage(for: context)
    }
    
    private func getSuggestedAction(for error: Error, context: ErrorContext) -> String {
        if let requestError = error as? RequestError {
            switch requestError {
            case .rateLimited, .throttled:
                return "Wait a moment, then tap Retry"
            case .duplicateRequest:
                return "Wait for current request to complete"
            case .castingError:
                return "Tap Retry to try again"
            }
        }
        
        if let networkError = error as? NetworkError {
            switch networkError {
            case .invalidResponse:
                return "Tap Retry to try again"
            case .decodingError:
                return "Tap Retry to reload the data"
            case .unknown:
                return "Check connection and tap Retry"
            case .badURL:
                return "Data temporarily unavailable"
            }
        }
        
        if (error as NSError).domain == NSURLErrorDomain {
            return "Check connection and tap Retry"
        }
        
        return "Tap Retry to try again"
    }
    
    // MARK: - Retry-Specific Message Generators
    
    private func getRetryAfterCooldownMessage(for context: ErrorContext) -> String {
        switch context.feature {
        case .chartData:
            return "Chart data temporarily limited. Tap Retry to try again."
        case .coinList:
            return "Coin data temporarily limited. Tap Retry to try again."
        case .search:
            return "Search temporarily limited. Tap Retry to try again."
        case .watchlist:
            return "Watchlist temporarily limited. Tap Retry to try again."
        case .priceUpdates:
            return "Price updates temporarily limited."
        }
    }
    
    private func getRetryServerBusyMessage(for context: ErrorContext) -> String {
        switch context.feature {
        case .chartData:
            return "Server busy loading chart data. Tap Retry to try again."
        case .coinList:
            return "Server busy loading coin data. Tap Retry to try again."
        case .search:
            return "Search service busy. Tap Retry to try again."
        case .watchlist:
            return "Watchlist service busy. Tap Retry to try again."
        case .priceUpdates:
            return "Price service busy."
        }
    }
    
    private func getRetryProcessingMessage(for context: ErrorContext) -> String {
        switch context.feature {
        case .chartData:
            return "Issue processing chart data. Tap Retry to reload."
        case .coinList:
            return "Issue processing coin data. Tap Retry to reload."
        case .search:
            return "Issue processing search results. Tap Retry to reload."
        case .watchlist:
            return "Issue processing watchlist. Tap Retry to reload."
        case .priceUpdates:
            return "Issue processing price updates."
        }
    }
    
    private func getRetryConnectionMessage(for context: ErrorContext) -> String {
        switch context.feature {
        case .chartData:
            return "Connection issue loading chart. Check internet and tap Retry."
        case .coinList:
            return "Connection issue loading coins. Check internet and tap Retry."
        case .search:
            return "Connection issue with search. Check internet and tap Retry."
        case .watchlist:
            return "Connection issue with watchlist. Check internet and tap Retry."
        case .priceUpdates:
            return "Connection issue with price updates."
        }
    }
    
    private func getRetryGenericMessage(for context: ErrorContext) -> String {
        switch context.feature {
        case .chartData:
            return "Unable to load chart data. Tap Retry to try again."
        case .coinList:
            return "Unable to load coin data. Tap Retry to try again."
        case .search:
            return "Unable to search. Tap Retry to try again."
        case .watchlist:
            return "Unable to load watchlist. Tap Retry to try again."
        case .priceUpdates:
            return "Unable to update prices."
        }
    }
    
    private func getNonRetryableMessage(for error: Error, context: ErrorContext) -> String {
        switch context.feature {
        case .chartData:
            return "Chart data temporarily unavailable."
        case .coinList:
            return "Coin data temporarily unavailable."
        case .search:
            return "Search temporarily unavailable."
        case .watchlist:
            return "Watchlist temporarily unavailable."
        case .priceUpdates:
            return "Price updates temporarily unavailable."
        }
    }
    
    // MARK: - Original Message Methods (Preserved for backward compatibility)
    
    private func getTemporarilyUnavailableMessage(for context: ErrorContext) -> String {
        switch context.feature {
        case .chartData(let symbol):
            return "Chart data for \(symbol) is temporarily unavailable due to rate limiting. Please try again in a moment."
        case .coinList:
            return "Coin data is temporarily unavailable due to rate limiting. Please try again in a moment."
        case .search:
            return "Search is temporarily unavailable due to rate limiting. Please try again in a moment."
        case .watchlist:
            return "Watchlist data is temporarily unavailable due to rate limiting. Please try again in a moment."
        case .priceUpdates:
            return "Price updates are temporarily slowed due to rate limiting."
        }
    }
    
    private func getThrottledMessage(for context: ErrorContext) -> String {
        switch context.feature {
        case .chartData(let symbol):
            return "Loading \(symbol) chart data... (requests are being paced to prevent rate limiting)"
        case .coinList:
            return "Loading coin data... (requests are being paced to prevent rate limiting)"
        case .search:
            return "Searching... (requests are being paced to prevent rate limiting)"
        case .watchlist:
            return "Loading watchlist... (requests are being paced to prevent rate limiting)"
        case .priceUpdates:
            return "Price updates are being paced to prevent rate limiting."
        }
    }
    
    private func getNotAvailableMessage(for context: ErrorContext) -> String {
        switch context.feature {
        case .chartData(let symbol):
            return "Chart data is not available for \(symbol) at this time."
        case .coinList:
            return "Coin data is not available at this time."
        case .search:
            return "Search is not available at this time."
        case .watchlist:
            return "Watchlist is not available at this time."
        case .priceUpdates:
            return "Price updates are not available at this time."
        }
    }
    
    private func getServiceBusyMessage(for context: ErrorContext) -> String {
        switch context.feature {
        case .chartData(let symbol):
            return "The chart service is busy. Unable to load \(symbol) data right now."
        case .coinList:
            return "The coin service is busy. Unable to load data right now."
        case .search:
            return "The search service is busy. Unable to search right now."
        case .watchlist:
            return "The watchlist service is busy. Unable to load data right now."
        case .priceUpdates:
            return "The price service is busy."
        }
    }
    
    private func getProcessingErrorMessage(for context: ErrorContext) -> String {
        switch context.feature {
        case .chartData:
            return "There was an issue processing the chart data. Please try again."
        case .coinList:
            return "There was an issue processing the coin data. Please try again."
        case .search:
            return "There was an issue processing the search results. Please try again."
        case .watchlist:
            return "There was an issue processing the watchlist data. Please try again."
        case .priceUpdates:
            return "There was an issue processing the price updates."
        }
    }
    
    private func getConnectionErrorMessage() -> String {
        return "Please check your internet connection and try again."
    }
    
    private func getGenericErrorMessage(for context: ErrorContext) -> String {
        switch context.feature {
        case .chartData:
            return "Unable to load chart data at this time. Please try again."
        case .coinList:
            return "Unable to load coin data at this time. Please try again."
        case .search:
            return "Unable to search at this time. Please try again."
        case .watchlist:
            return "Unable to load watchlist at this time. Please try again."
        case .priceUpdates:
            return "Unable to update prices at this time."
        }
    }
}

// MARK: - Retry Error Info

/**
 * RetryErrorInfo
 * 
 * Contains comprehensive error information including retry availability
 */
struct RetryErrorInfo: Equatable {
    let message: String
    let isRetryable: Bool
    let suggestedAction: String
}

// MARK: - Error Context

/**
 * ErrorContext
 * 
 * Provides context information for generating personalized error messages.
 * Allows the same error to have different messages based on where it occurred.
 */
struct ErrorContext {
    let feature: FeatureContext
    
    enum FeatureContext {
        case chartData(symbol: String)
        case coinList
        case search
        case watchlist
        case priceUpdates
    }
}

// MARK: - Convenience Extensions

extension ErrorMessageProvider {
    
    // Chart-specific convenience method for retry info
    func getChartRetryInfo(for error: Error, symbol: String) -> RetryErrorInfo {
        let context = ErrorContext(feature: .chartData(symbol: symbol))
        return getRetryInfo(for: error, context: context)
    }
    
    // Coin list convenience method for retry info  
    func getCoinListRetryInfo(for error: Error) -> RetryErrorInfo {
        let context = ErrorContext(feature: .coinList)
        return getRetryInfo(for: error, context: context)
    }
    
    // Search convenience method for retry info
    func getSearchRetryInfo(for error: Error) -> RetryErrorInfo {
        let context = ErrorContext(feature: .search)
        return getRetryInfo(for: error, context: context)
    }
    
    // Watchlist convenience method for retry info
    func getWatchlistRetryInfo(for error: Error) -> RetryErrorInfo {
        let context = ErrorContext(feature: .watchlist)
        return getRetryInfo(for: error, context: context)
    }
    
    // Chart-specific convenience method (preserved for backward compatibility)

} 