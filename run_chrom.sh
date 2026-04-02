# 1. Wipe the Flutter build cache (removes the 'build/' and '.dart_tool/' folders)
echo "🧹 Cleaning Flutter cache..."
flutter clean

# 2. Re-fetch all packages from pub.dev
echo "📦 Fetching fresh packages..."
flutter pub get

# 3. If you are on Mac testing iOS, clean the pods too
# cd ios && rm -rf Pods && rm Podfile.lock && pod install && cd ..

# 4. Launch in Chrome while ignoring the browser cache
echo "🚀 Launching with clean slate..."
flutter run -d chrome --web-port 8080 --release