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
    
    // MARK: - Context-Specific Message Templates
    
    private func getTemporarilyUnavailableMessage(for context: ErrorContext) -> String {
        switch context.feature {
        case .chartData(let symbol):
            return "Chart data for \(symbol) is temporarily unavailable due to high demand. Please wait a moment and try again."
        case .coinList:
            return "Coin data is temporarily unavailable due to high demand. Please wait a moment and try again."
        case .search:
            return "Search is temporarily unavailable. Please wait a moment and try again."
        case .watchlist:
            return "Watchlist data is temporarily unavailable. Please wait a moment and try again."
        case .priceUpdates:
            return "Price updates are temporarily unavailable. Please wait a moment for automatic retry."
        }
    }
    
    private func getThrottledMessage(for context: ErrorContext) -> String {
        switch context.feature {
        case .chartData:
            return "Please wait a moment before switching chart ranges again."
        case .coinList:
            return "Please wait a moment before refreshing the coin list again."
        case .search:
            return "Please wait a moment before searching again."
        case .watchlist:
            return "Please wait a moment before updating your watchlist again."
        case .priceUpdates:
            return "Price updates are being throttled to prevent excessive requests."
        }
    }
    
    private func getNotAvailableMessage(for context: ErrorContext) -> String {
        switch context.feature {
        case .chartData(let symbol):
            return "Chart data is not available for \(symbol) at this time."
        case .coinList:
            return "Coin list data is not available at this time."
        case .search:
            return "Search functionality is not available at this time."
        case .watchlist:
            return "Watchlist data is not available at this time."
        case .priceUpdates:
            return "Price updates are not available at this time."
        }
    }
    
    private func getServiceBusyMessage(for context: ErrorContext) -> String {
        switch context.feature {
        case .chartData:
            return "Unable to load chart data. The service may be temporarily busy. Please try again in a few moments."
        case .coinList:
            return "Unable to load coin data. The service may be temporarily busy. Please try again in a few moments."
        case .search:
            return "Unable to search. The service may be temporarily busy. Please try again in a few moments."
        case .watchlist:
            return "Unable to load watchlist. The service may be temporarily busy. Please try again in a few moments."
        case .priceUpdates:
            return "Unable to update prices. The service may be temporarily busy."
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
    
    // Chart-specific convenience method
    func getChartErrorMessage(for error: Error, symbol: String) -> String {
        let context = ErrorContext(feature: .chartData(symbol: symbol))
        return getMessage(for: error, context: context)
    }
    
    // Generic convenience methods
    func getCoinListErrorMessage(for error: Error) -> String {
        let context = ErrorContext(feature: .coinList)
        return getMessage(for: error, context: context)
    }
    
    func getSearchErrorMessage(for error: Error) -> String {
        let context = ErrorContext(feature: .search)
        return getMessage(for: error, context: context)
    }
    
    func getWatchlistErrorMessage(for error: Error) -> String {
        let context = ErrorContext(feature: .watchlist)
        return getMessage(for: error, context: context)
    }
    
    func getPriceUpdateErrorMessage(for error: Error) -> String {
        let context = ErrorContext(feature: .priceUpdates)
        return getMessage(for: error, context: context)
    }
} 