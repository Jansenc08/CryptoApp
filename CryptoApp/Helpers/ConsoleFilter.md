# Console Filtering Guide

## 🧹 Filter Out iOS System Warnings

### Problem
Your console is cluttered with harmless iOS system messages like:
```
nw_connection_copy_connected_local_endpoint_block_invoke [C3] Client called nw_connection_copy_connected_local_endpoint on unconnected nw_connection
```

### Solution: Xcode Console Filter

1. **Open Xcode Console** (when running your app)
2. **Find the filter box** at the bottom of the console
3. **Add this filter** to hide system warnings:

```
-nw_connection -libnetwork -[NetworkLoadMetrics]
```

### Alternative: Environment Variable

Add this to your Xcode scheme to reduce network logging:

1. **Edit Scheme** → **Run** → **Environment Variables**
2. **Add**: `OS_ACTIVITY_MODE` = `disable`

### What These Messages Mean

- `nw_connection_copy_*`: iOS Network.framework internal messages
- **Harmless**: Your network requests still work perfectly
- **Common**: Appears during API calls (especially rapid/concurrent ones)
- **Debug only**: Less verbose in production builds

### Your App's Real Logs

Look for these organized categories instead:
- `🗄️ DB | ...` - Database operations
- `🌐 NET | ...` - Network requests  
- `📱 UI | ...` - User interface updates
- `💰 PRICE | ...` - Price data updates
- `📈 CHART | ...` - Chart updates

These are the logs that matter for debugging your CryptoApp! 