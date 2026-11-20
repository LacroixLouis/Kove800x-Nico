#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v xcodebuild >/dev/null 2>&1; then
    echo "La compilation iPhone demande Xcode sur macOS (ordinateur ou service de compilation)." >&2
    exit 1
fi

mkdir -p build
check_dir="$(mktemp -d "$PWD/build/check-XXXXXXXX")"
python3 scripts/tests/test_mac_scripts.py 2>&1 | tee "$check_dir/script-tests.log"
swift test 2>&1 | tee "$check_dir/swift-tests.log"
xcodebuild \
    -project NicoMirror.xcodeproj \
    -scheme NicoMirror \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -derivedDataPath build/DerivedData \
    -resultBundlePath "$check_dir/Compilation.xcresult" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    build 2>&1 | tee "$check_dir/build.log"

mkdir -p build/Payload
cp -R build/DerivedData/Build/Products/Release-iphoneos/KoveMirror.app build/Payload/
(cd build && zip -qr NicoMirror-non-signe.ipa Payload)
echo "Produit : build/NicoMirror-non-signe.ipa — nécessite une signature avant installation."
