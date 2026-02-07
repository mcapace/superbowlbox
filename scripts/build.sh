#!/usr/bin/env bash
# Build SuperBowlBox from the command line. App supports iOS 17+; testing uses iOS 26.3 (e.g. iPhone 17). Do not use iPhone 16.
set -e
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

# Prefer iPhone 17 (typical test device on iOS 26.x)
DEST='platform=iOS Simulator,name=iPhone 17'
if ! xcodebuild -scheme SuperBowlBox -destination "$DEST" -quiet build 2>/dev/null; then
  # Fallback: use first available iPhone simulator
  DEST='platform=iOS Simulator,name=iPhone 17 Pro'
  xcodebuild -scheme SuperBowlBox -destination "$DEST" -quiet build
fi
