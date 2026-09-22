#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint lc0.podspec' to validate before publishing.
#
require 'yaml'

pubspec = YAML.load(File.read(File.join(__dir__, '../pubspec.yaml')))

Pod::Spec.new do |s|
  s.name             = pubspec['name']
  s.version          = pubspec['version']
  s.summary          = pubspec['description']
  s.homepage         = pubspec['homepage']
  s.license          = { :file => '../LICENSE', :type => 'GPL-3.0' }
  s.author           = 'LeelaChessZero Authors'
  s.source           = { :git => pubspec['repository'], :tag => s.version.to_s }

  # Source files
  s.source_files = [
    'Classes/**/*',
    'FlutterLc0/**/*.{cpp,h}',
    # Core lc0 source (including .mm for Metal backend)
    'lc0/src/**/*.{cc,h,mm}',
    # Generated proto headers
    'lc0/build/**/*.h',
    # Third party headers
    'lc0/third_party/**/*.h',
    # BLAS backend for simulator support
    'lc0/src/neural/backends/blas/*.{cc,h}',
    'lc0/src/neural/backends/shared/*.{cc,h}',
  ]

  # Header files
  s.public_header_files = 'Classes/**/*.h'

  # Exclude GPU backends, tests, and files that aren't needed for iOS
  s.exclude_files = [
    'lc0/src/**/*_test.cc',
    'lc0/src/neural/backends/cuda/**/*',
    'lc0/src/neural/backends/dx/**/*',
    'lc0/src/neural/backends/opencl/**/*',
    'lc0/src/neural/backends/onednn/**/*',
    'lc0/src/neural/backends/sycl/**/*',
    'lc0/src/neural/backends/xla/**/*',
    'lc0/src/neural/backends/network_onnx.cc',
    'lc0/src/neural/backends/network_tf_cc.cc',
    'lc0/src/rescorer_main.cc',
    'lc0/src/trainingdata/rescorer.cc',
    # Exclude dag_classic search (uses abseil, we use classic search)
    'lc0/src/search/dag_classic/**/*',
    # Exclude Windows-specific files
    'lc0/src/utils/filesystem.win32.cc',
  ]

  s.dependency 'Flutter'
  s.platform = :ios, '13.0'
  s.ios.deployment_target = '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++20',
    'CLANG_CXX_LIBRARY' => 'libc++',
    'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) USE_BLAS=1 NO_POPCNT=1 NO_F16C=1 NO_PEXT=1 IS_64BIT=1',
    'OTHER_CPLUSPLUSFLAGS' => '$(inherited) -std=c++20 -fobjc-arc',
    'HEADER_SEARCH_PATHS' => '$(inherited) "${PODS_TARGET_SRCROOT}/eigen_header" "${PODS_TARGET_SRCROOT}/lc0/build" "${PODS_TARGET_SRCROOT}/lc0/build/proto"',
    'USER_HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}/lc0/src" "${PODS_TARGET_SRCROOT}/lc0/third_party" "${PODS_TARGET_SRCROOT}/lc0"',
  }

  # C++ and Objective-C++ configuration
  s.library = 'c++', 'z'
  s.frameworks = 'Accelerate', 'Metal', 'MetalPerformanceShaders', 'MetalPerformanceShadersGraph', 'Foundation'

  # Script phases for generating proto headers
  s.script_phase = [
    {
      :execution_position => :before_compile,
      :name => 'Generate Proto Headers',
      :script => <<-SCRIPT
cd "${PODS_TARGET_SRCROOT}/lc0"
mkdir -p build/proto
python3 scripts/compile_proto.py proto/net.proto --proto_path=. --cpp_out=build || true
python3 scripts/compile_proto.py proto/onnx.proto --proto_path=. --cpp_out=build || true
python3 scripts/compile_proto.py proto/hlo.proto --proto_path=. --cpp_out=build || true
# Create config headers
cat > build/build_id.h << 'EOF'
#pragma once
#define BUILD_IDENTIFIER "flutter-ios"
EOF
cat > build/default_search.h << 'EOF'
#pragma once
#define DEFAULT_SEARCH "classic"
EOF
cat > build/default_backend.h << 'EOF'
#pragma once
#include <TargetConditionals.h>
#if TARGET_OS_SIMULATOR
#define DEFAULT_BACKEND "blas"
#else
#define DEFAULT_BACKEND "metal"
#endif
EOF
cat > build/trace_config.h << 'EOF'
#pragma once
EOF
      SCRIPT
    }
  ]

end
