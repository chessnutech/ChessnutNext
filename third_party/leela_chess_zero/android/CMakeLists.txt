cmake_minimum_required(VERSION 3.14)
project(lc0)

# Enable 16KB page size support for Android (required for Google Play)
add_link_options(-Wl,-z,max-page-size=16384)
add_link_options(-Wl,-z,common-page-size=16384)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Base paths
set(LC0_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../ios/lc0)
set(LC0_SRC ${LC0_DIR}/src)
set(LC0_BUILD ${LC0_DIR}/build)
set(FFI_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../ios/FlutterLc0)
set(LC0_GENERATED_PROTO_DIR ${CMAKE_CURRENT_BINARY_DIR}/proto)

# Include directories
include_directories(
    ${CMAKE_CURRENT_BINARY_DIR}  # For generated headers - MUST be first to override iOS build headers
    ${LC0_SRC}
    ${LC0_BUILD}
    ${LC0_DIR}/third_party
    ${LC0_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}  # For cblas.h
)

# Generate LC0's lightweight protobuf headers for Android builds. The upstream
# Meson build does this, but the Flutter plugin CMake build needs the same step.
if(NOT DEFINED Python3_EXECUTABLE)
    if(DEFINED ENV{Python3_EXECUTABLE} AND NOT "$ENV{Python3_EXECUTABLE}" STREQUAL "")
        set(Python3_EXECUTABLE "$ENV{Python3_EXECUTABLE}" CACHE FILEPATH "Python3 executable" FORCE)
    elseif(DEFINED ENV{PYTHON_EXECUTABLE} AND NOT "$ENV{PYTHON_EXECUTABLE}" STREQUAL "")
        set(Python3_EXECUTABLE "$ENV{PYTHON_EXECUTABLE}" CACHE FILEPATH "Python3 executable" FORCE)
    endif()
endif()
find_package(Python3 COMPONENTS Interpreter REQUIRED)
set(LC0_PROTO_HEADERS
    ${LC0_GENERATED_PROTO_DIR}/net.pb.h
    ${LC0_GENERATED_PROTO_DIR}/onnx.pb.h
    ${LC0_GENERATED_PROTO_DIR}/hlo.pb.h
)
foreach(LC0_PROTO_NAME net onnx hlo)
    add_custom_command(
        OUTPUT ${LC0_GENERATED_PROTO_DIR}/${LC0_PROTO_NAME}.pb.h
        COMMAND ${Python3_EXECUTABLE}
            ${LC0_DIR}/scripts/compile_proto.py
            --proto_path=${LC0_DIR}
            --cpp_out=${CMAKE_CURRENT_BINARY_DIR}
            ${LC0_DIR}/proto/${LC0_PROTO_NAME}.proto
        DEPENDS
            ${LC0_DIR}/scripts/compile_proto.py
            ${LC0_DIR}/proto/${LC0_PROTO_NAME}.proto
        VERBATIM
    )
endforeach()
add_custom_target(lc0_proto_headers DEPENDS ${LC0_PROTO_HEADERS})

# Fetch dependencies
include(FetchContent)

# Eigen (header-only library) - disable tests/benchmarks
set(BUILD_TESTING OFF CACHE BOOL "" FORCE)
set(EIGEN_BUILD_DOC OFF CACHE BOOL "" FORCE)
set(EIGEN_BUILD_PKGCONFIG OFF CACHE BOOL "" FORCE)
set(EIGEN_BUILD_TESTING OFF CACHE BOOL "" FORCE)

FetchContent_Declare(
    eigen
    GIT_REPOSITORY https://gitlab.com/libeigen/eigen.git
    GIT_TAG 3.4.0
    GIT_SHALLOW TRUE
)

# Get Eigen but don't add subdirectory (header-only)
FetchContent_GetProperties(eigen)
if(NOT eigen_POPULATED)
    FetchContent_Populate(eigen)
endif()

# Just add include path for Eigen (header-only library)
include_directories(${eigen_SOURCE_DIR})

# Abseil not needed - we use our lightweight absl_compat.h on Android

# Find zlib (available on Android NDK)
find_library(ZLIB_LIBRARY z)
find_path(ZLIB_INCLUDE_DIR zlib.h)
include_directories(${ZLIB_INCLUDE_DIR})

# Common source files (from meson.build common_files)
set(COMMON_SOURCES
    ${LC0_SRC}/chess/board.cc
    ${LC0_SRC}/chess/gamestate.cc
    ${LC0_SRC}/chess/position.cc
    ${LC0_SRC}/chess/uciloop.cc
    ${LC0_SRC}/neural/backend.cc
    ${LC0_SRC}/neural/batchsplit.cc
    ${LC0_SRC}/neural/decoder.cc
    ${LC0_SRC}/neural/encoder.cc
    ${LC0_SRC}/neural/factory.cc
    ${LC0_SRC}/neural/loader.cc
    ${LC0_SRC}/neural/register.cc
    ${LC0_SRC}/neural/shared_params.cc
    ${LC0_SRC}/neural/wrapper.cc
    ${LC0_SRC}/search/classic/node.cc
    ${LC0_SRC}/syzygy/syzygy.cc
    ${LC0_SRC}/trainingdata/reader.cc
    ${LC0_SRC}/trainingdata/trainingdata.cc
    ${LC0_SRC}/trainingdata/writer.cc
    ${LC0_SRC}/utils/commandline.cc
    ${LC0_SRC}/utils/configfile.cc
    ${LC0_SRC}/utils/esc_codes.cc
    ${LC0_SRC}/utils/files.cc
    ${LC0_SRC}/utils/logging.cc
    ${LC0_SRC}/utils/optionsdict.cc
    ${LC0_SRC}/utils/optionsparser.cc
    ${LC0_SRC}/utils/protomessage.cc
    ${LC0_SRC}/utils/random.cc
    ${LC0_SRC}/utils/lc0_string.cc
    ${LC0_SRC}/utils/trace.cc
    ${LC0_SRC}/version.cc
    ${LC0_SRC}/utils/filesystem.posix.cc
)

# Main engine files
set(ENGINE_SOURCES
    ${LC0_SRC}/engine_loop.cc
    ${LC0_SRC}/engine.cc
    ${LC0_SRC}/neural/backends/network_check.cc
    ${LC0_SRC}/neural/backends/network_demux.cc
    ${LC0_SRC}/neural/backends/network_mux.cc
    ${LC0_SRC}/neural/backends/network_random.cc
    ${LC0_SRC}/neural/backends/network_record.cc
    ${LC0_SRC}/neural/backends/network_rr.cc
    ${LC0_SRC}/neural/backends/network_trivial.cc
    ${LC0_SRC}/neural/memcache.cc
    ${LC0_SRC}/neural/network_legacy.cc
    ${LC0_SRC}/neural/onnx/adapters.cc
    ${LC0_SRC}/neural/onnx/builder.cc
    ${LC0_SRC}/neural/onnx/converter.cc
    ${LC0_SRC}/neural/xla/hlo_builder.cc
    ${LC0_SRC}/neural/xla/onnx2hlo.cc
    ${LC0_SRC}/neural/xla/print_hlo.cc
    ${LC0_SRC}/neural/xla/xla_tensor.cc
    ${LC0_SRC}/search/classic/params.cc
    ${LC0_SRC}/search/classic/search.cc
    ${LC0_SRC}/search/classic/stoppers/alphazero.cc
    ${LC0_SRC}/search/classic/stoppers/common.cc
    ${LC0_SRC}/search/classic/stoppers/factory.cc
    ${LC0_SRC}/search/classic/stoppers/legacy.cc
    ${LC0_SRC}/search/classic/stoppers/simple.cc
    ${LC0_SRC}/search/classic/stoppers/smooth.cc
    ${LC0_SRC}/search/classic/stoppers/stoppers.cc
    ${LC0_SRC}/search/classic/stoppers/timemgr.cc
    ${LC0_SRC}/search/classic/wrapper.cc
    ${LC0_SRC}/search/register.cc
    ${LC0_SRC}/selfplay/game.cc
    ${LC0_SRC}/selfplay/loop.cc
    ${LC0_SRC}/selfplay/multigame.cc
    ${LC0_SRC}/selfplay/tournament.cc
    ${LC0_SRC}/tools/backendbench.cc
    ${LC0_SRC}/tools/benchmark.cc
    ${LC0_SRC}/tools/describenet.cc
    ${LC0_SRC}/tools/leela2onnx.cc
    ${LC0_SRC}/tools/onnx2leela.cc
    ${LC0_SRC}/utils/histogram.cc
    ${LC0_SRC}/utils/numa.cc
    ${LC0_SRC}/utils/weights_adapter.cc
    ${LC0_SRC}/search/instamove/instamove.cc
)

# BLAS backend files (CPU-based neural network inference)
set(BLAS_SOURCES
    ${LC0_SRC}/neural/backends/blas/convolution1.cc
    ${LC0_SRC}/neural/backends/blas/fully_connected_layer.cc
    ${LC0_SRC}/neural/backends/blas/se_unit.cc
    ${LC0_SRC}/neural/backends/blas/network_blas.cc
    ${LC0_SRC}/neural/backends/blas/winograd_convolution3.cc
)

# Shared backend files
set(SHARED_SOURCES
    ${LC0_SRC}/neural/backends/shared/activation.cc
    ${LC0_SRC}/neural/backends/shared/winograd_filter.cc
)

# FFI bridge
set(FFI_SOURCES
    ${FFI_DIR}/ffi.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/blas_init.cc
)

# Main entry point
set(MAIN_SOURCES
    ${LC0_SRC}/main.cc
)

# Generate build configuration headers
file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/build_id.h
"#pragma once
#define BUILD_IDENTIFIER \"flutter-android\"
")

file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/default_search.h
"#pragma once
#define DEFAULT_SEARCH \"classic\"
")

file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/default_backend.h
"#pragma once
#define DEFAULT_BACKEND \"blas\"
")

file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/trace_config.h
"#pragma once
// No tracing enabled for mobile builds
")

# Common compile definitions
# USE_OPENBLAS - for including cblas.h and using our Eigen-based CBLAS implementation
# USE_BLAS - to enable the non-Eigen BLAS code paths and register "blas" backend
set(LC0_COMPILE_DEFS USE_OPENBLAS USE_BLAS NO_POPCNT NO_F16C NO_PEXT)
set(LC0_COMPILE_OPTS -fexceptions -frtti -fno-function-sections -fno-data-sections)

# Use OBJECT library for BLAS backend - this ensures static registration is preserved
add_library(lc0_blas OBJECT ${BLAS_SOURCES} ${SHARED_SOURCES})
add_dependencies(lc0_blas lc0_proto_headers)
target_compile_definitions(lc0_blas PRIVATE ${LC0_COMPILE_DEFS})
target_compile_options(lc0_blas PRIVATE ${LC0_COMPILE_OPTS})
set_target_properties(lc0_blas PROPERTIES POSITION_INDEPENDENT_CODE ON)

# Create the shared library - include BLAS objects directly
add_library(lc0 SHARED
    ${FFI_SOURCES}
    ${COMMON_SOURCES}
    ${ENGINE_SOURCES}
    ${MAIN_SOURCES}
    $<TARGET_OBJECTS:lc0_blas>
)
add_dependencies(lc0 lc0_proto_headers)

# Link libraries
target_link_libraries(lc0
    ${ZLIB_LIBRARY}
    log
)

# Compile definitions
target_compile_definitions(lc0 PRIVATE ${LC0_COMPILE_DEFS})

# Enable exceptions and disable function/data sections stripping
target_compile_options(lc0 PRIVATE ${LC0_COMPILE_OPTS})

# Prevent linker from stripping unused sections (important for static registration)
target_link_options(lc0 PRIVATE -Wl,--no-gc-sections)

# Architecture-specific options
if(ANDROID_ABI STREQUAL "arm64-v8a")
    target_compile_definitions(lc0 PRIVATE IS_64BIT)
    target_compile_definitions(lc0_blas PRIVATE IS_64BIT)
    if(CMAKE_BUILD_TYPE STREQUAL "Release")
        target_compile_options(lc0 PRIVATE -O3 -DNDEBUG)
        target_compile_options(lc0_blas PRIVATE -O3 -DNDEBUG)
    endif()
elseif(ANDROID_ABI STREQUAL "x86_64")
    target_compile_definitions(lc0 PRIVATE IS_64BIT)
    target_compile_definitions(lc0_blas PRIVATE IS_64BIT)
    if(CMAKE_BUILD_TYPE STREQUAL "Release")
        target_compile_options(lc0 PRIVATE -O3 -DNDEBUG)
        target_compile_options(lc0_blas PRIVATE -O3 -DNDEBUG)
    endif()
else()
    if(CMAKE_BUILD_TYPE STREQUAL "Release")
        target_compile_options(lc0 PRIVATE -O3 -DNDEBUG)
        target_compile_options(lc0_blas PRIVATE -O3 -DNDEBUG)
    endif()
endif()
