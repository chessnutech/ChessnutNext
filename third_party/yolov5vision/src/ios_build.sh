#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
BUILD_DIR="$SCRIPT_DIR/ios_build"
FRAMEWORK="$BUILD_DIR/Release-iphoneos/vision.framework"
XCFRAMEWORK="$BUILD_DIR/vision.xcframework"
POD_FRAMEWORK_DIR="$SCRIPT_DIR/../ios/Frameworks"
POD_XCFRAMEWORK="$POD_FRAMEWORK_DIR/vision.xcframework"

cmake -E remove_directory "$BUILD_DIR"
cmake -S "$SCRIPT_DIR" -B "$BUILD_DIR" -G Xcode \
  -DCMAKE_TOOLCHAIN_FILE="$SCRIPT_DIR/ios.toolchain.cmake" \
  -DPLATFORM=OS64 \
  -DUCI_BUILD_TYPE=ios
cmake --build "$BUILD_DIR" --target vision --config Release -- \
  CODE_SIGNING_ALLOWED=NO

xcodebuild -create-xcframework \
  -framework "$FRAMEWORK" \
  -output "$XCFRAMEWORK"

cmake -E make_directory "$POD_FRAMEWORK_DIR"
cmake -E remove_directory "$POD_XCFRAMEWORK"
cmake -E copy_directory "$XCFRAMEWORK" "$POD_XCFRAMEWORK"

echo "Created $POD_XCFRAMEWORK"
