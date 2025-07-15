#!/bin/bash

echo "🔧 Fixing Xcode indexing issues..."

# Step 1: Close Xcode completely
echo "1. Please close Xcode completely first!"
read -p "Press Enter when Xcode is closed..."

# Step 2: Clear all caches
echo "2. Clearing all Xcode caches..."
rm -rf ~/Library/Developer/Xcode/DerivedData
rm -rf ~/Library/Caches/com.apple.dt.Xcode*
rm -rf ~/Library/Saved\ Application\ State/com.apple.dt.Xcode.savedState

# Step 3: Clear workspace state
echo "3. Clearing workspace state..."
rm -rf CryptoApp.xcworkspace/xcuserdata

# Step 4: Clear project state
echo "4. Clearing project state..."
rm -rf CryptoApp.xcodeproj/xcuserdata

# Step 5: Reset SPM
echo "5. Resetting Swift Package Manager..."
rm -rf CryptoApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
rm -rf CryptoApp.xcworkspace/xcshareddata/swiftpm/Package.resolved

echo "✅ Cleanup complete!"
echo ""
echo "🚀 Now do this:"
echo "1. Open Xcode"
echo "2. File → Open → CryptoApp.xcworkspace"
echo "3. Wait for indexing to complete"
echo "4. Product → Clean Build Folder (⌘⇧K)"
echo "5. Product → Build (⌘B)"
echo ""
echo "The indexing should now work correctly!" 