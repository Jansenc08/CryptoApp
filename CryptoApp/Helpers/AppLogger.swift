import Foundation

/// Centralized logging system for CryptoApp
/// Provides organized, visually clear debug output with different categories
final class AppLogger {
    
    static let shared = AppLogger()
    private init() {}
    
    // MARK: - Log Categories
    
    /// Database operations (Core Data, WatchlistManager)
    static func database(_ message: String, level: LogLevel = .info) {
        shared.log("🗄️ DB", message, level: level)
    }
    
    /// Network requests and API calls
    static func network(_ message: String, level: LogLevel = .info) {
        shared.log("🌐 NET", message, level: level)
    }
    
    /// UI updates and view lifecycle
    static func ui(_ message: String, level: LogLevel = .info) {
        shared.log("📱 UI", message, level: level)
    }
    
    /// Data processing and transformations
    static func data(_ message: String, level: LogLevel = .info) {
        shared.log("📊 DATA", message, level: level)
    }
    
    /// Price updates and financial data
    static func price(_ message: String, level: LogLevel = .info) {
        shared.log("💰 PRICE", message, level: level)
    }
    
    /// Search functionality
    static func search(_ message: String, level: LogLevel = .info) {
        shared.log("🔍 SEARCH", message, level: level)
    }
    
    /// Chart and visualization updates
    static func chart(_ message: String, level: LogLevel = .info) {
        shared.log("📈 CHART", message, level: level)
    }
    
    /// Performance metrics and optimizations
    static func performance(_ message: String, level: LogLevel = .info) {
        shared.log("⚡ PERF", message, level: level)
    }
    
    /// Error conditions
    static func error(_ message: String, error: Error? = nil) {
        let errorDetail = error != nil ? " | \(error!.localizedDescription)" : ""
        shared.log("❌ ERROR", message + errorDetail, level: .error)
    }
    
    /// Success operations
    static func success(_ message: String) {
        shared.log("✅ SUCCESS", message, level: .success)
    }
    
    /// Cache operations
    static func cache(_ message: String, level: LogLevel = .info) {
        shared.log("💾 CACHE", message, level: level)
    }
    
    // MARK: - Log Levels
    
    enum LogLevel {
        case info, warning, error, success, debug
        
        var emoji: String {
            switch self {
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "🚨"
            case .success: return "🎉"
            case .debug: return "🔧"
            }
        }
    }
    
    // MARK: - Core Logging
    
    private func log(_ category: String, _ message: String, level: LogLevel) {
        #if DEBUG
        let timestamp = DateFormatter.timeFormatter.string(from: Date())
        let levelEmoji = level.emoji
        
        switch level {
        case .error:
            print("[\(timestamp)] \(levelEmoji) \(category) | \(message)")
        case .success:
            print("[\(timestamp)] \(levelEmoji) \(category) | \(message)")
        case .warning:
            print("[\(timestamp)] \(levelEmoji) \(category) | \(message)")
        default:
            print("[\(timestamp)] \(category) | \(message)")
        }
        #endif
    }
    
    // MARK: - System Message Filtering
    
    /// Suppresses common iOS system warnings that clutter the console
    static func suppressSystemWarnings() {
        #if DEBUG
        // This would need to be implemented at the OS level
        // For now, we just document that these nw_connection warnings are normal
        #endif
    }
    
    // MARK: - Special Formatters
    
    /// Log database contents in a formatted table
    static func databaseTable(_ title: String, items: [(String, String)]) {
        #if DEBUG
        print("\n" + "═".repeating(50))
        print("🗄️ \(title.uppercased())")
        print("═".repeating(50))
        if items.isEmpty {
            print("📝 No items found")
        } else {
            for (index, item) in items.enumerated() {
                print("\(index + 1). \(item.0): \(item.1)")
            }
        }
        print("═".repeating(50) + "\n")
        #endif
    }
    
    /// Log price updates in a formatted table
    static func priceTable(_ title: String, updates: [(symbol: String, oldPrice: String, newPrice: String, change: String)]) {
        #if DEBUG
        print("\n" + "─".repeating(60))
        print("💰 \(title.uppercased())")
        print("─".repeating(60))
        if updates.isEmpty {
            print("📝 No price updates")
        } else {
            for update in updates {
                let arrow = update.change.hasPrefix("+") ? "📈" : "📉"
                print("\(arrow) \(update.symbol): \(update.oldPrice) → \(update.newPrice) (\(update.change))")
            }
        }
        print("─".repeating(60) + "\n")
        #endif
    }
    
    /// Log API request summary
    static func apiSummary(endpoint: String, status: Int, itemCount: Int? = nil, duration: TimeInterval? = nil) {
        let countText = itemCount != nil ? " | \(itemCount!) items" : ""
        let durationText = duration != nil ? " | \(String(format: "%.2f", duration! * 1000))ms" : ""
        AppLogger.network("\(endpoint) | HTTP \(status)\(countText)\(durationText)")
    }
    

}

// MARK: - Extensions

private extension DateFormatter {
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}

private extension String {
    func repeating(_ count: Int) -> String {
        return String(repeating: self, count: count)
    }
} 