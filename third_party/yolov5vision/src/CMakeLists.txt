# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

include(FetchContent)

project(vision_library VERSION 0.0.1)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -g")

add_library(vision SHARED
  yolov5ncnn.cpp
)

set(LOCAL_PREBUILT_ROOT
  "$ENV{LOCALAPPDATA}/Temp/chessnut-v3-cmake-prebuilt"
  CACHE PATH "Local prebuilt dependency cache root"
)

function(fetch_prebuilt_archive dependency_name archive_url archive_sha256)
  if(EXISTS "${LOCAL_PREBUILT_ROOT}/${dependency_name}" AND
     IS_DIRECTORY "${LOCAL_PREBUILT_ROOT}/${dependency_name}")
    set(${dependency_name}_SOURCE_DIR
      "${LOCAL_PREBUILT_ROOT}/${dependency_name}"
      PARENT_SCOPE
    )
    return()
  endif()
  FetchContent_Declare(
    ${dependency_name}
    URL ${archive_url}
    URL_HASH SHA256=${archive_sha256}
  )
  FetchContent_MakeAvailable(${dependency_name})
  set(${dependency_name}_SOURCE_DIR "${${dependency_name}_SOURCE_DIR}" PARENT_SCOPE)
endfunction()

set(NCNN_VERSION "20250916" CACHE STRING "ncnn prebuilt release version")
set(NCNN_ANDROID_SHA256 "29bee787a120f2410708bca4e9450975ce084861ff92d9e79d0e39c92291248e" CACHE STRING "ncnn Android prebuilt archive SHA256")
set(NCNN_IOS_SHA256 "1b9c6aaf5d3f7baa7446b2def6abe72f8de9449fca436bba499ca2b2b9c28b60" CACHE STRING "ncnn iOS prebuilt archive SHA256")
set(NCNN_MACOS_SHA256 "9897ad0b866b7935a9d337b835cb55e3c6a8df20364b983802e49bb51d48af01" CACHE STRING "ncnn macOS prebuilt archive SHA256")
set(NCNN_WINDOWS_VS2022_SHA256 "9f8820f72a3cde2aa687ff9f445ccfc993df63cf35ec5969c540cb38a33b611f" CACHE STRING "ncnn Windows VS2022 prebuilt archive SHA256")
set(OPENCV_MOBILE_VERSION "4.12.0" CACHE STRING "opencv-mobile prebuilt release version")
set(OPENCV_MOBILE_RELEASE_TAG "v34" CACHE STRING "opencv-mobile GitHub release tag")
set(OPENCV_MOBILE_ANDROID_SHA256 "d2561021f763ec45b81ebf20681460f9bbcde5c97ac0af9a367c1e3c82caf56a" CACHE STRING "opencv-mobile Android prebuilt archive SHA256")
set(OPENCV_MOBILE_IOS_SHA256 "31ac61408c9b2db20da27c58474a4fdbe32b242a14976b385f5e4c533d57ea2c" CACHE STRING "opencv-mobile iOS prebuilt archive SHA256")
set(OPENCV_MOBILE_MACOS_SHA256 "af5a19f9c4458f3ea91faf7339a987ff0b27f9e6a61fa9243d41db3432f5acc0" CACHE STRING "opencv-mobile macOS prebuilt archive SHA256")
set(OPENCV_MOBILE_WINDOWS_VS2022_SHA256 "a55d4f505821c68d0d0ad9637c3186cf1a1517ab9315b8373bf09af0684de17c" CACHE STRING "opencv-mobile Windows VS2022 prebuilt archive SHA256")

if(APPLE)
  if(UCI_BUILD_TYPE STREQUAL "ios")
    set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_CURRENT_LIST_DIR}/ios_build/lib)
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_CURRENT_LIST_DIR}/ios_build/bin)
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_CURRENT_LIST_DIR}/ios_build/bin)

    fetch_prebuilt_archive(
      ncnn_apple
      "https://github.com/Tencent/ncnn/releases/download/${NCNN_VERSION}/ncnn-${NCNN_VERSION}-ios.zip"
      "${NCNN_IOS_SHA256}"
    )
    fetch_prebuilt_archive(
      opencv_mobile_apple
      "https://github.com/nihui/opencv-mobile/releases/download/${OPENCV_MOBILE_RELEASE_TAG}/opencv-mobile-${OPENCV_MOBILE_VERSION}-ios.zip"
      "${OPENCV_MOBILE_IOS_SHA256}"
    )
  elseif(UCI_BUILD_TYPE STREQUAL "mac")
    set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_CURRENT_LIST_DIR}/mac_build/lib)
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_CURRENT_LIST_DIR}/mac_build/bin)
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_CURRENT_LIST_DIR}/mac_build/bin)

    fetch_prebuilt_archive(
      ncnn_apple
      "https://github.com/Tencent/ncnn/releases/download/${NCNN_VERSION}/ncnn-${NCNN_VERSION}-macos.zip"
      "${NCNN_MACOS_SHA256}"
    )
    fetch_prebuilt_archive(
      opencv_mobile_apple
      "https://github.com/nihui/opencv-mobile/releases/download/${OPENCV_MOBILE_RELEASE_TAG}/opencv-mobile-${OPENCV_MOBILE_VERSION}-macos.zip"
      "${OPENCV_MOBILE_MACOS_SHA256}"
    )
  else()
    message(FATAL_ERROR "UCI_BUILD_TYPE must be 'ios' or 'mac' for Apple builds")
  endif()

  find_library(OPENMP_FRAMEWORK openmp PATHS "${ncnn_apple_SOURCE_DIR}" NO_DEFAULT_PATH)
  find_library(NCNN_FRAMEWORK ncnn PATHS "${ncnn_apple_SOURCE_DIR}" NO_DEFAULT_PATH)

  # FetchContent strips OpenCV's sole top-level framework directory. Restore
  # the wrapper with a symlink so Xcode retains normal framework semantics.
  set(OPENCV_FRAMEWORK_ROOT "${CMAKE_CURRENT_BINARY_DIR}/opencv-framework")
  file(MAKE_DIRECTORY "${OPENCV_FRAMEWORK_ROOT}")
  file(REMOVE "${OPENCV_FRAMEWORK_ROOT}/opencv2.framework")
  execute_process(
    COMMAND ${CMAKE_COMMAND} -E create_symlink
      "${opencv_mobile_apple_SOURCE_DIR}"
      "${OPENCV_FRAMEWORK_ROOT}/opencv2.framework"
    RESULT_VARIABLE OPENCV_FRAMEWORK_LINK_RESULT
  )
  if(NOT OPENCV_FRAMEWORK_LINK_RESULT EQUAL 0)
    message(FATAL_ERROR "Failed to create the OpenCV framework wrapper")
  endif()
  find_library(OPENCV_FRAMEWORK opencv2 PATHS "${OPENCV_FRAMEWORK_ROOT}" NO_DEFAULT_PATH)

  if(NOT OPENMP_FRAMEWORK OR NOT NCNN_FRAMEWORK OR NOT OPENCV_FRAMEWORK)
    message(FATAL_ERROR "One or more downloaded Apple frameworks could not be found")
  endif()

  target_link_libraries(vision PRIVATE
    ${NCNN_FRAMEWORK}
    ${OPENMP_FRAMEWORK}
    ${OPENCV_FRAMEWORK}
  )
endif()

if(ANDROID)
fetch_prebuilt_archive(
  ncnn_android
  "https://github.com/Tencent/ncnn/releases/download/${NCNN_VERSION}/ncnn-${NCNN_VERSION}-android.zip"
  "${NCNN_ANDROID_SHA256}"
)
set(ncnn_DIR "${ncnn_android_SOURCE_DIR}/${ANDROID_ABI}/lib/cmake/ncnn")
find_package(ncnn REQUIRED)
target_link_libraries(vision PRIVATE ncnn)

fetch_prebuilt_archive(
  opencv_mobile_android
  "https://github.com/nihui/opencv-mobile/releases/download/${OPENCV_MOBILE_RELEASE_TAG}/opencv-mobile-${OPENCV_MOBILE_VERSION}-android.zip"
  "${OPENCV_MOBILE_ANDROID_SHA256}"
)
set(OpenCV_DIR "${opencv_mobile_android_SOURCE_DIR}/sdk/native/jni")
find_package(OpenCV REQUIRED)
target_include_directories(vision PRIVATE "${OpenCV_DIR}/include")
target_link_libraries(vision PRIVATE ${OpenCV_LIBS})
endif()

if(WIN32)
if(CMAKE_GENERATOR_PLATFORM MATCHES "^(ARM64|arm64)$" OR CMAKE_SYSTEM_PROCESSOR MATCHES "^(ARM64|arm64|aarch64)$")
  set(WINDOWS_PREBUILT_ARCH "arm64")
else()
  set(WINDOWS_PREBUILT_ARCH "x64")
endif()

fetch_prebuilt_archive(
  ncnn_windows
  "https://github.com/Tencent/ncnn/releases/download/${NCNN_VERSION}/ncnn-${NCNN_VERSION}-windows-vs2022.zip"
  "${NCNN_WINDOWS_VS2022_SHA256}"
)
set(ncnn_DIR "${ncnn_windows_SOURCE_DIR}/${WINDOWS_PREBUILT_ARCH}/lib/cmake/ncnn")
find_package(ncnn REQUIRED)
target_link_libraries(vision PRIVATE ncnn)

fetch_prebuilt_archive(
  opencv_mobile_windows
  "https://github.com/nihui/opencv-mobile/releases/download/${OPENCV_MOBILE_RELEASE_TAG}/opencv-mobile-${OPENCV_MOBILE_VERSION}-windows-vs2022.zip"
  "${OPENCV_MOBILE_WINDOWS_VS2022_SHA256}"
)
set(OpenCV_DIR "${opencv_mobile_windows_SOURCE_DIR}/${WINDOWS_PREBUILT_ARCH}")
set(OpenCV_STATIC ON)
find_package(OpenCV REQUIRED)
target_include_directories(vision PRIVATE ${OpenCV_INCLUDE_DIRS})
target_link_libraries(vision PRIVATE ${OpenCV_LIBS})
endif()

FetchContent_Declare(
  json
  URL https://github.com/nlohmann/json/releases/download/v3.11.3/json.tar.xz
)
if(EXISTS "${LOCAL_PREBUILT_ROOT}/json" AND
   IS_DIRECTORY "${LOCAL_PREBUILT_ROOT}/json")
  add_subdirectory(
    "${LOCAL_PREBUILT_ROOT}/json"
    "${CMAKE_CURRENT_BINARY_DIR}/json-prebuilt"
  )
else()
  FetchContent_MakeAvailable(json)
endif()

target_link_libraries(vision PRIVATE nlohmann_json::nlohmann_json)

set_target_properties(vision PROPERTIES
  PUBLIC_HEADER vision.h
  OUTPUT_NAME "vision"
  FRAMEWORK TRUE
  FRAMEWORK_VERSION A
  MACOSX_FRAMEWORK_IDENTIFIER com.chessnutech.vision
  # "current version" in semantic format in Mach-O binary file
  VERSION 16.4.0
  # "compatibility version" in semantic format in Mach-O binary file
  SOVERSION 1.0.0
  MACOSX_FRAMEWORK_SHORT_VERSION_STRING "${PROJECT_VERSION}" #CFBundleShortVersionString
  MACOSX_FRAMEWORK_BUNDLE_VERSION 1 #CFBundleVersion
  XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY "iPhone Developer"
  XCODE_ATTRIBUTE_DEBUG_INFORMATION_FORMAT "dwarf-with-dsym"
)

target_compile_definitions(vision PUBLIC DART_SHARED_LIB)

if (ANDROID)
  # Support Android 15 16k page size
  target_link_options(vision PRIVATE "-Wl,-z,max-page-size=16384")
endif()

# add_executable(example_yolo example.cpp)
# target_link_libraries(example_yolo PRIVATE vision)

# if(${UCI_BUILD_TYPE} MATCHES "ios")
# target_link_libraries(example_yolo PRIVATE ${OPENCV_FRAMEWORK})
# endif()

# if(${UCI_BUILD_TYPE} MATCHES "mac")
# target_link_libraries(example_yolo PRIVATE ${OPENCV_FRAMEWORK})
# endif()
