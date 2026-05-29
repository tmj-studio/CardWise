#!/bin/bash
# take_screenshots.sh — Build the app, launch on simulator, and capture tab screenshots
# Usage: ./Scripts/take_screenshots.sh
#
# NOTE: This script temporarily patches MainTabView.swift to accept a SCREENSHOT_TAB
# environment variable, then reverts the change after screenshots are taken.
# Requirements: Xcode 15+, iOS Simulator

set -e

PROJ_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEVICE="iPhone 17 Pro"
BUNDLE_ID="com.cardwise.app"
SCHEME="CardWise"
SCREENSHOT_DIR="$PROJ_DIR/Screenshots"
TAB_VIEW="$PROJ_DIR/CardWise/Views/MainTabView.swift"

mkdir -p "$SCREENSHOT_DIR"

# ----- Patch MainTabView to accept SCREENSHOT_TAB env var -----
echo "==> Patching MainTabView for screenshot mode..."
sed -i '' 's/@State private var selectedTab = 0/@State private var selectedTab: Int = { if let t = ProcessInfo.processInfo.environment["SCREENSHOT_TAB"], let n = Int(t) { return n }; return 0 }()/' "$TAB_VIEW"

cleanup() {
  echo "==> Reverting MainTabView patch..."
  sed -i '' 's/@State private var selectedTab: Int = {.*}()/@State private var selectedTab = 0/' "$TAB_VIEW"
}
trap cleanup EXIT

# ----- Build -----
echo "==> Building app..."
xcodebuild -project "$PROJ_DIR/CardWise.xcodeproj" \
  -scheme "$SCHEME" \
  -sdk iphonesimulator \
  -destination "platform=iOS Simulator,name=$DEVICE" \
  -configuration Debug \
  build 2>&1 | tail -5

APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -path "*/CardWise*/Build/Products/Debug-iphonesimulator/CardWise.app" -maxdepth 5 | head -1)
if [ -z "$APP_PATH" ]; then
  echo "ERROR: Could not find built .app"
  exit 1
fi
echo "==> App at: $APP_PATH"

# ----- Boot simulator -----
echo "==> Booting simulator ($DEVICE)..."
xcrun simctl boot "$DEVICE" 2>/dev/null || true
open -a Simulator
sleep 3

# ----- Install -----
echo "==> Installing app..."
xcrun simctl install "$DEVICE" "$APP_PATH"

echo "==> Setting onboarding flag..."
xcrun simctl spawn "$DEVICE" defaults write "$BUNDLE_ID" hasCompletedOnboarding -bool true

# ----- Screenshot helper -----
screenshot_tab() {
  local tab=$1
  local filename=$2

  xcrun simctl terminate "$DEVICE" "$BUNDLE_ID" 2>/dev/null || true
  sleep 0.5

  SIMCTL_CHILD_SCREENSHOT_TAB="$tab" xcrun simctl launch "$DEVICE" "$BUNDLE_ID"
  sleep 3

  xcrun simctl io "$DEVICE" screenshot "$SCREENSHOT_DIR/$filename"
  echo "    Saved $filename"
}

# ----- Capture each tab -----
echo "==> Taking screenshots..."

echo "  [1/4] Home"
screenshot_tab 0 home.png

echo "  [2/4] My Cards"
screenshot_tab 1 cards.png

echo "  [3/4] Recommend"
screenshot_tab 2 recommend.png

echo "  [4/4] Spending"
screenshot_tab 3 spending.png

echo ""
echo "==> Done! Screenshots saved to $SCREENSHOT_DIR/"
ls -la "$SCREENSHOT_DIR"
