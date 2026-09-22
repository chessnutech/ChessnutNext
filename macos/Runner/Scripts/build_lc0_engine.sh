#!/bin/sh
set -eu

APP_ROOT="${PROJECT_DIR}/.."
LC0_DIR="${APP_ROOT}/third_party/leela_chess_zero/ios/lc0"
BUILD_ROOT="${DERIVED_FILE_DIR}/ChessnutLc0"
ENGINE_BUILD="${BUILD_ROOT}/lc0"
ENGINE_DEST_DIR="${TARGET_BUILD_DIR}/${EXECUTABLE_FOLDER_PATH}"
ENGINE_DEST="${ENGINE_DEST_DIR}/lc0"

if [ ! -d "${LC0_DIR}" ]; then
  echo "error: LC0 source directory not found: ${LC0_DIR}" >&2
  exit 1
fi

mkdir -p "${BUILD_ROOT}" "${ENGINE_DEST_DIR}"

PATH="${HOME}/Library/Python/3.9/bin:${HOME}/.local/bin:${PATH}"
MESON="$(command -v meson || true)"
NINJA="$(command -v ninja || true)"

if [ -z "${MESON}" ] || [ -z "${NINJA}" ]; then
  PYTHONUSERBASE="${BUILD_ROOT}/python-user-base"
  export PYTHONUSERBASE
  PATH="${PYTHONUSERBASE}/bin:${PATH}"
  export PATH
  python3 -m pip install --user -i https://pypi.tuna.tsinghua.edu.cn/simple meson ninja
  MESON="$(command -v meson || true)"
  NINJA="$(command -v ninja || true)"
fi

if [ -z "${MESON}" ] || [ -z "${NINJA}" ]; then
  echo "error: meson and ninja are required to build bundled LC0." >&2
  exit 1
fi

cd "${LC0_DIR}"

MESON_SETUP_ARGS="--buildtype release -Dgtest=false -Dopenblas=false -Daccelerate=true -Dopencl=false -Dmetal=disabled -Donnx=false -Dxla=false -Dtensorflow=false -Dispc=false -Dnative_arch=false -Ddefault_backend=blas -Ddefault_search=classic -Ddag_classic=false"

EXPECTED_ARCHS="${ARCHS:-$(uname -m)}"
BUILT_COUNT=0
FIRST_ENGINE=""
SECOND_ENGINE=""

for arch in ${EXPECTED_ARCHS}; do
  case "${arch}" in
    arm64)
      CROSS_FILE="${LC0_DIR}/cross-files/aarch64-darwin"
      ARCH_BUILD_DIR="${BUILD_ROOT}/arm64"
      ;;
    x86_64)
      CROSS_FILE="${LC0_DIR}/cross-files/x86_64-darwin"
      ARCH_BUILD_DIR="${BUILD_ROOT}/x86_64"
      ;;
    *)
      echo "error: Unsupported LC0 macOS architecture: ${arch}" >&2
      exit 1
      ;;
  esac

  if [ -f "${ARCH_BUILD_DIR}/build.ninja" ]; then
    # shellcheck disable=SC2086
    "${MESON}" setup "${ARCH_BUILD_DIR}" --reconfigure --cross-file "${CROSS_FILE}" ${MESON_SETUP_ARGS}
  else
    # shellcheck disable=SC2086
    "${MESON}" setup "${ARCH_BUILD_DIR}" --cross-file "${CROSS_FILE}" ${MESON_SETUP_ARGS}
  fi

  "${MESON}" compile -C "${ARCH_BUILD_DIR}"
  ARCH_ENGINE="${ARCH_BUILD_DIR}/lc0"
  if [ ! -x "${ARCH_ENGINE}" ]; then
    echo "error: LC0 build did not produce ${ARCH_ENGINE}" >&2
    exit 1
  fi

  if [ "${BUILT_COUNT}" -eq 0 ]; then
    FIRST_ENGINE="${ARCH_ENGINE}"
  elif [ "${BUILT_COUNT}" -eq 1 ]; then
    SECOND_ENGINE="${ARCH_ENGINE}"
  else
    echo "error: LC0 build script supports up to two macOS architectures." >&2
    exit 1
  fi
  BUILT_COUNT=$((BUILT_COUNT + 1))
done

if [ "${BUILT_COUNT}" -eq 1 ]; then
  cp -f "${FIRST_ENGINE}" "${ENGINE_BUILD}"
else
  lipo -create "${FIRST_ENGINE}" "${SECOND_ENGINE}" -output "${ENGINE_BUILD}"
fi

cp -f "${ENGINE_BUILD}" "${ENGINE_DEST}"
chmod 755 "${ENGINE_DEST}"

if [ "${CODE_SIGNING_ALLOWED:-NO}" != "NO" ] && command -v codesign >/dev/null 2>&1; then
  SIGN_IDENTITY="${EXPANDED_CODE_SIGN_IDENTITY:-}"
  if [ -n "${SIGN_IDENTITY}" ]; then
    set -- --force --sign "${SIGN_IDENTITY}"
  else
    set -- --force --sign -
  fi

  if [ -f "${PROJECT_DIR}/Runner/Lc0.entitlements" ]; then
    codesign "$@" --entitlements "${PROJECT_DIR}/Runner/Lc0.entitlements" "${ENGINE_DEST}"
  else
    codesign "$@" "${ENGINE_DEST}"
  fi

  codesign -d --entitlements - "${ENGINE_DEST}" 2>&1 | \
    grep -q 'com.apple.security.app-sandbox' || {
      echo "error: Bundled LC0 is missing the App Sandbox entitlement." >&2
      exit 1
    }
fi
