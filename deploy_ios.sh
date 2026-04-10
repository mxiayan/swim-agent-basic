#!/bin/bash

# --- 1. Cleanup and Sync ---
echo "🧹 Cleaning Flutter build artifacts..."
flutter clean

echo "📦 Fetching dependencies..."
flutter pub get

# --- 2. iOS Native Sync ---
echo "🍎 Updating CocoaPods..."
cd ios
# Use --repo-update to ensure you have the latest Firebase/Flutter pods
pod install --repo-update
cd ..

# --- 3. Production Build ---
echo "🏗️  Building iOS Release IPA..."
# This generates the files Xcode needs for the Archive
flutter build ios --release --no-codesign

# --- 4. Final Step ---
echo "🚀 Opening Xcode for Archiving..."
echo "Instructions: Go to 'Product' -> 'Archive', then 'Distribute App' -> 'TestFlight'."
open ios/Runner.xcworkspace
