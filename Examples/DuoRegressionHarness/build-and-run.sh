#!/bin/bash
set -euo pipefail

# An iOS app bundle for real Device Hub testing, without adding a shipped package target.
harness_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
repo_dir="$(cd -- "$harness_dir/../.." && pwd)"
device_id="${1:?Usage: bash build-and-run.sh SIMULATOR-UUID}"
build_dir="${TMPDIR:-/tmp}/swiftfulrouting-duo-harness"
app_dir="$build_dir/DuoRegression.app"
derived_dir="$build_dir/DerivedData"
mkdir -p "$app_dir"
cd "$repo_dir"
xcodebuild build -scheme SwiftfulRouting -destination "platform=iOS Simulator,id=$device_id" \
    -derivedDataPath "$derived_dir" CLANG_ENABLE_CODE_COVERAGE=NO CODE_SIGNING_ALLOWED=NO > "$build_dir/build.log" 2>&1
products_dir="$derived_dir/Build/Products/Debug-iphonesimulator"
sdk_path="$(xcrun --sdk iphonesimulator --show-sdk-path)"
host_arch="$(uname -m)"
xcrun --sdk iphonesimulator swiftc -parse-as-library -swift-version 6 -profile-generate -sdk "$sdk_path" \
    -target "$host_arch-apple-ios27.1-simulator" -I "$products_dir" \
    -Xlinker -syslibroot -Xlinker "$sdk_path" \
    "$harness_dir"/*.swift "$products_dir/SwiftfulRouting.o" "$products_dir/SwiftfulRecursiveUI.o" \
    -o "$app_dir/DuoRegression"
cat > "$app_dir/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.swiftfulrouting.DuoRegression</string>
<key>CFBundleExecutable</key><string>DuoRegression</string>
<key>CFBundleName</key><string>Duo Regression</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>MinimumOSVersion</key><string>27.1</string>
<key>LSRequiresIPhoneOS</key><true/>
<key>UIDeviceFamily</key><array><integer>1</integer><integer>2</integer></array>
<key>UILaunchScreen</key><dict/>
<key>UIApplicationSceneManifest</key><dict><key>UIApplicationSupportsMultipleScenes</key><true/></dict>
<key>UISupportedInterfaceOrientations</key><array>
<string>UIInterfaceOrientationPortrait</string><string>UIInterfaceOrientationPortraitUpsideDown</string>
<string>UIInterfaceOrientationLandscapeLeft</string><string>UIInterfaceOrientationLandscapeRight</string>
</array>
</dict></plist>
PLIST
harness_build_id="$(date -u +%Y%m%d%H%M%S)"
plutil -replace CFBundleVersion -string "$harness_build_id" "$app_dir/Info.plist"
codesign --force --sign - "$app_dir"
if [ "${2:-}" = "--build-only" ]; then
    printf 'Built harness: %s\n' "$app_dir"
    exit 0
fi
xcrun simctl bootstatus "$device_id" -b
xcrun simctl terminate "$device_id" com.swiftfulrouting.DuoRegression >/dev/null 2>&1 || true
xcrun simctl install "$device_id" "$app_dir"
xcrun simctl launch --terminate-running-process "$device_id" com.swiftfulrouting.DuoRegression --prepare-branch "${@:2}"
report_dir="$(xcrun simctl get_app_container "$device_id" com.swiftfulrouting.DuoRegression data)"
printf 'Harness running. Report: %s/Documents/duo-regression.json\n' "$report_dir"
