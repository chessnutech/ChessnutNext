#!/bin/sh
set -eu

APP_ROOT="${PROJECT_DIR}/.."
SRC_DIR="${APP_ROOT}/third_party/stockfish/ios/Stockfish/src"
NNUE_DIR="${APP_ROOT}/third_party/stockfish/android/nnue"
BUILD_DIR="${DERIVED_FILE_DIR}/ChessnutStockfish"
ENGINE_BUILD="${BUILD_DIR}/stockfish"
ENGINE_DEST_DIR="${TARGET_BUILD_DIR}/${EXECUTABLE_FOLDER_PATH}"
RESOURCE_DEST_DIR="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/stockfish"
ENGINE_DEST="${ENGINE_DEST_DIR}/stockfish"

BIG_NET="nn-c288c895ea92.nnue"
SMALL_NET="nn-37f18f62d772.nnue"

if [ ! -d "${SRC_DIR}" ]; then
  echo "error: Stockfish source directory not found: ${SRC_DIR}" >&2
  exit 1
fi

mkdir -p "${BUILD_DIR}" "${ENGINE_DEST_DIR}" "${RESOURCE_DEST_DIR}"

EXPECTED_ARCHS="${ARCHS:-$(uname -m)}"
NEEDS_BUILD=0

if [ ! -x "${ENGINE_BUILD}" ]; then
  NEEDS_BUILD=1
elif [ -n "$(find "${SRC_DIR}" -name '*.cpp' -newer "${ENGINE_BUILD}" -print -quit)" ]; then
  NEEDS_BUILD=1
else
  BUILT_ARCHS="$(lipo -archs "${ENGINE_BUILD}" 2>/dev/null || true)"
  for arch in ${EXPECTED_ARCHS}; do
    case " ${BUILT_ARCHS} " in
      *" ${arch} "*) ;;
      *) NEEDS_BUILD=1 ;;
    esac
  done
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  echo "Building bundled Stockfish engine..."
  ARCH_FLAGS=""
  for arch in ${EXPECTED_ARCHS}; do
    ARCH_FLAGS="${ARCH_FLAGS} -arch ${arch}"
  done
  # shellcheck disable=SC2086
  find "${SRC_DIR}" -name '*.cpp' -print0 | \
    xargs -0 xcrun clang++ \
      ${ARCH_FLAGS} \
      -std=c++17 \
      -O2 \
      -DNDEBUG \
      -DUSE_PTHREADS \
      -DIS_64BIT \
      -pthread \
      -I"${SRC_DIR}" \
      -Wa,-I"${SRC_DIR}" \
      -o "${ENGINE_BUILD}"
fi

cp -f "${ENGINE_BUILD}" "${ENGINE_DEST}"
chmod 755 "${ENGINE_DEST}"

for net in "${BIG_NET}" "${SMALL_NET}"; do
  NET_SOURCE="${NNUE_DIR}/${net}"
  if [ ! -f "${NET_SOURCE}" ]; then
    NET_SOURCE="${SRC_DIR}/${net}"
  fi
  if [ ! -f "${NET_SOURCE}" ]; then
    echo "error: Stockfish NNUE file not found: ${NNUE_DIR}/${net} or ${SRC_DIR}/${net}" >&2
    exit 1
  fi
  cp -f "${NET_SOURCE}" "${RESOURCE_DEST_DIR}/${net}"
done

if [ "${CODE_SIGNING_ALLOWED:-NO}" != "NO" ] && command -v codesign >/dev/null 2>&1; then
  SIGN_IDENTITY="${EXPANDED_CODE_SIGN_IDENTITY:-}"
  if [ -n "${SIGN_IDENTITY}" ]; then
    set -- --force --sign "${SIGN_IDENTITY}"
  else
    set -- --force --sign -
  fi

  if [ -f "${PROJECT_DIR}/Runner/Stockfish.entitlements" ]; then
    codesign "$@" --entitlements "${PROJECT_DIR}/Runner/Stockfish.entitlements" "${ENGINE_DEST}"
  else
    codesign "$@" "${ENGINE_DEST}"
  fi

  codesign -d --entitlements - "${ENGINE_DEST}" 2>&1 | \
    grep -q 'com.apple.security.app-sandbox' || {
      echo "error: Bundled Stockfish is missing the App Sandbox entitlement." >&2
      exit 1
    }
fi
