#!/bin/bash
# Builds the test app for the iOS simulator without an Xcode project: one Swift file plus Info.plist.
set -euo pipefail
cd "$(dirname "$0")/.."

APP=build/EdgeEffectTest.app
rm -rf build
mkdir -p "$APP"

SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
xcrun --sdk iphonesimulator swiftc -parse-as-library -O \
  -target "$(uname -m)-apple-ios26.0-simulator" -sdk "$SDK" \
  App/EdgeEffectTest.swift -o "$APP/EdgeEffectTest"
cp App/Info.plist "$APP/Info.plist"
codesign --force --sign - "$APP"
echo "Built $APP with $(xcrun --sdk iphonesimulator --show-sdk-version) simulator SDK"
