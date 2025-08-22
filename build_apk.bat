@echo off
REM ChatApp Build Script for Windows
REM This script helps build the release APK for your project

echo 🚀 Building ChatApp for Android...
echo ==================================

REM Clean previous builds
echo 🧹 Cleaning previous builds...
flutter clean

REM Get dependencies
echo 📦 Getting dependencies...
flutter pub get

REM Build the APK
echo 🏗️ Building release APK...
flutter build apk --release

REM Check if build was successful
if %ERRORLEVEL% == 0 (
    echo ✅ Build successful!
    echo 📱 APK location: build\app\outputs\flutter-apk\app-release.apk
    echo.
    echo 📋 Build Information:
    echo    - Target: Android API 28+
    echo    - Architecture: ARM64, ARM, x64
    echo    - Build type: Release
    echo.
    echo 🎯 Next steps:
    echo    1. Test the APK on different devices
    echo    2. Share the APK file for submission
    echo    3. Record demonstration video
) else (
    echo ❌ Build failed! Please check the errors above.
    pause
    exit /b 1
)

pause
