#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint stockfish.podspec' to validate before publishing.
#
#
require 'yaml'

pubspec = YAML.load(File.read(File.join(__dir__, '../pubspec.yaml')))

Pod::Spec.new do |s|
  s.name             = pubspec['name']
  s.version          = pubspec['version']
  s.summary          = pubspec['description']
  s.homepage         = pubspec['homepage']
  s.license          = { :file => '../LICENSE', :type => 'MIT' }
  s.author           = 'Arjan Aswal'
  s.source = { :git => pubspec['repository'], :tag => s.version.to_s }
  s.source_files = 'Classes/**/*', 'FlutterStockfish/*', 'Stockfish/src/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.exclude_files = 'Stockfish/src/incbin/UNLICENCE'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'
  s.ios.deployment_target  = '12.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }

  # Additional compiler configuration required for Stockfish
  s.library = 'c++'
  nnue_script = <<-'SCRIPT'
set -e

stockfish_root="${PODS_TARGET_SRCROOT}/.."
src_dir="${PODS_TARGET_SRCROOT}/Stockfish/src"
android_nnue_dir="${stockfish_root}/android/nnue"

install_nnue() {
  name="$1"
  expected_sha="$2"
  src_file="${src_dir}/${name}"
  android_file="${android_nnue_dir}/${name}"

  if [ ! -f "${src_file}" ] || [ "$(shasum -a 256 "${src_file}" | awk '{print $1}')" != "${expected_sha}" ]; then
    if [ -f "${android_file}" ] && [ "$(shasum -a 256 "${android_file}" | awk '{print $1}')" = "${expected_sha}" ]; then
      cp -f "${android_file}" "${src_file}"
    fi
  fi

  actual_sha="$(shasum -a 256 "${src_file}" | awk '{print $1}')"
  if [ "${actual_sha}" != "${expected_sha}" ]; then
    echo "error: ${name} checksum mismatch. Expected ${expected_sha}, got ${actual_sha}."
    exit 1
  fi

  cp -f "${src_file}" "${PODS_ROOT}/${name}"
}

install_nnue "nn-c288c895ea92.nnue" "c288c895ea924429ea9092e3f36b2b3c1f00f2a3a4c759ff7e57e79e3b43e4a7"
install_nnue "nn-37f18f62d772.nnue" "37f18f62d772f3107e1d6aaca3898c130c3c86f2ab63e6555fbbca20635a899d"
  SCRIPT

  s.script_phase = {
    :execution_position => :before_compile,
    :name => 'Install Stockfish NNUE',
    :script => nnue_script
  }
  s.xcconfig = {
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    'CLANG_CXX_LIBRARY' => 'libc++',
    'OTHER_CPLUSPLUSFLAGS[config=Debug]' => '$(inherited) -std=c++17 -DUSE_PTHREADS -DIS_64BIT -DUSE_POPCNT -I"${PODS_TARGET_SRCROOT}/Stockfish/src" -Wa,-I"${PODS_TARGET_SRCROOT}/Stockfish/src"',
    'OTHER_LDFLAGS[config=Debug]' => '$(inherited) -std=c++17 -DUSE_PTHREADS -DIS_64BIT -DUSE_POPCNT',
    'OTHER_CPLUSPLUSFLAGS[config=Release]' => '$(inherited) -fno-exceptions -std=c++17 -DUSE_PTHREADS -DNDEBUG -O3 -DIS_64BIT -DUSE_POPCNT -DUSE_NEON=8 -flto=full -I"${PODS_TARGET_SRCROOT}/Stockfish/src" -Wa,-I"${PODS_TARGET_SRCROOT}/Stockfish/src"',
    'OTHER_LDFLAGS[config=Release]' => '$(inherited) -fno-exceptions -std=c++17 -DUSE_PTHREADS -DNDEBUG -O3 -DIS_64BIT -DUSE_POPCNT -DUSE_NEON=8 -flto=full'
  }
end
