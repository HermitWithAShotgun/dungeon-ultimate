#!/usr/bin/env bash
# Build the pinned stable-diffusion.cpp CUDA shared engine for Linux.
# The upstream release only ships a Windows CUDA build; Linux CUDA is built here
# from the exact same commit the FFI layer was written against.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DU_ROOT="${DU_ROOT:-$(dirname "$ROOT_DIR")/data}"
OUT_DIR="$DU_ROOT/models/runtime/sd"
CACHE_DIR="${DU_DOWNLOAD_CACHE:-$ROOT_DIR/.cache}"
SRC_DIR="$CACHE_DIR/sdcpp"
REV="master-956-1b0ba10"
COMMIT="1b0ba10893f4e2e0656103011fc1c4645a02a734"

if [[ -f "$OUT_DIR/libstable-diffusion.so" ]]; then
  echo "==> Engine already present: $OUT_DIR/libstable-diffusion.so"
  exit 0
fi

echo "==> Installing cmake (user site, no sudo)"
PIP_REQUIRE_VIRTUALENV=0 python -m pip install --quiet --no-input 'cmake==3.31.10'

mkdir -p "$CACHE_DIR"
if [[ ! -d "$SRC_DIR/.git" ]]; then
  echo "==> Cloning stable-diffusion.cpp at $REV"
  git clone --depth 1 --branch "$REV" https://github.com/leejet/stable-diffusion.cpp.git "$SRC_DIR"
fi
cd "$SRC_DIR"
for attempt in 1 2 3 4 5; do
  if git submodule update --init --recursive; then break; fi
  echo "==> Submodule fetch $attempt failed; retrying"
  sleep 10
done

echo "==> Configuring CUDA build (sm_80..120, flash attention for all quants)"
rm -rf build && mkdir build && cd build
# The Pinokio/conda env injects -O2 via CFLAGS; clear it so vendored C code builds cleanly.
CLEAN() { env -u CC -u CXX -u CFLAGS -u CXXFLAGS -u CPPFLAGS -u LDFLAGS -u CPATH -u C_INCLUDE_PATH "$@"; }
CLEAN cmake .. \
  -DSD_BUILD_SHARED_LIBS=ON \
  -DSD_CUDA=ON \
  -DSD_BUILD_SHARED_GGML_LIB=ON \
  -DGGML_BACKEND_DL=ON \
  -DGGML_NATIVE=OFF \
  -DGGML_CPU_ALL_VARIANTS=ON \
  -DGGML_CUDA_FA_ALL_QUANTS=ON \
  -DCMAKE_CUDA_ARCHITECTURES='80;86;89;90;100;120' \
  -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON \
  -DCMAKE_INSTALL_RPATH='$ORIGIN' \
  -DCMAKE_CUDA_FLAGS='-Xcudafe --diag_suppress=177 -Xcudafe --diag_suppress=550'

echo "==> Compiling (this takes a while)"
CLEAN cmake --build . --config Release -j"$(nproc)"

mkdir -p "$OUT_DIR"
cp -a bin/. "$OUT_DIR"/
echo "==> Installed engine into $OUT_DIR"
"$OUT_DIR/sd-server" --help 2>&1 | head -2 || true
