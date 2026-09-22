#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
BUILD_DIR="$SCRIPT_DIR/mac_build"
FRAMEWORK="$BUILD_DIR/Release/vision.framework"
XCFRAMEWORK="$BUILD_DIR/vision.xcframework"
POD_FRAMEWORK_DIR="$SCRIPT_DIR/../macos/Frameworks"
POD_XCFRAMEWORK="$POD_FRAMEWORK_DIR/vision.xcframework"

cmake -E remove_directory "$BUILD_DIR"
cmake -S "$SCRIPT_DIR" -B "$BUILD_DIR" -G Xcode \
  -DCMAKE_TOOLCHAIN_FILE="$SCRIPT_DIR/ios.toolchain.cmake" \
  -DPLATFORM=MAC_UNIVERSAL \
  -DUCI_BUILD_TYPE=mac
cmake --build "$BUILD_DIR" --target vision --config Release -- \
  CODE_SIGNING_ALLOWED=NO

xcodebuild -create-xcframework \
  -framework "$FRAMEWORK" \
  -output "$XCFRAMEWORK"

cmake -E make_directory "$POD_FRAMEWORK_DIR"
cmake -E remove_directory "$POD_XCFRAMEWORK"
ditto "$XCFRAMEWORK" "$POD_XCFRAMEWORK"

echo "Created $POD_XCFRAMEWORK"
