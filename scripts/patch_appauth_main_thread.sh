#!/bin/bash
# Patches AppAuth-iOS so presentationAnchorForWebAuthenticationSession reads
# view.window on the main thread, fixing Main Thread Checker violations.
# Run before building (e.g. Build Pre-Action or first Run Script phase).
# Requires BUILD_DIR (e.g. from Xcode build settings).

set -e
# SPM checkouts are in DerivedData/ProjectHash/SourcePackages/checkouts (Build is DerivedData/ProjectHash/Build/...)
CHECKOUTS_ROOT="${CHECKOUTS_ROOT:-$(dirname "$(dirname "$(dirname "$BUILD_DIR")")")/SourcePackages/checkouts}"
APPAUTH_FILE="${CHECKOUTS_ROOT}/AppAuth-iOS/Sources/AppAuth/iOS/OIDExternalUserAgentIOS.m"

if [ -z "$BUILD_DIR" ]; then
  echo "patch_appauth_main_thread.sh: BUILD_DIR not set, skipping (ok if not building yet)."
  exit 0
fi

if [ ! -f "$APPAUTH_FILE" ]; then
  echo "patch_appauth_main_thread.sh: AppAuth file not found at $APPAUTH_FILE (run a build once to resolve packages)."
  exit 0
fi

if grep -q "NSThread isMainThread" "$APPAUTH_FILE"; then
  echo "patch_appauth_main_thread.sh: AppAuth already patched."
  exit 0
fi

# Replace the single-line return with main-thread dispatch (idempotent).
perl -i -0pe 's/return _presentingViewController\.view\.window;/__block ASPresentationAnchor anchor = nil;\n  if ([NSThread isMainThread]) {\n    anchor = _presentingViewController.view.window;\n  } else {\n    dispatch_sync(dispatch_get_main_queue(), ^{\n      anchor = _presentingViewController.view.window;\n    });\n  }\n  return anchor;/s' "$APPAUTH_FILE"

echo "patch_appauth_main_thread.sh: Patched AppAuth for main-thread presentation anchor."
echo "  If this ran in a Run Script phase (not Pre-Action): do Product > Clean Build Folder, then build again."
