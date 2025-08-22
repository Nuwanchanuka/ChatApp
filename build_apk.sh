#!/bin/bash

# ChatApp Build Script
# This script helps build the release APK for your project

echo "🚀 Building ChatApp for Android..."
echo "=================================="

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Run code generation if needed
echo "🔄 Running code generation..."
flutter packages pub run build_runner build --delete-conflicting-outputs

# Build the APK
echo "🏗️ Building release APK..."
flutter build apk --release

# Check if build was successful
if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    echo "📱 APK location: build/app/outputs/flutter-apk/app-release.apk"
    echo ""
    echo "📋 Build Information:"
    echo "   - Target: Android API 28+"
    echo "   - Architecture: ARM64, ARM, x64"
    echo "   - Build type: Release"
    echo ""
    echo "🎯 Next steps:"
    echo "   1. Test the APK on different devices"
    echo "   2. Share the APK file for submission"
    echo "   3. Record demonstration video"
else
    echo "❌ Build failed! Please check the errors above."
    exit 1
fi
