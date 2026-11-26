#!/usr/bin/env bash
# Build the headless server on Linux (no Tauri desktop shell).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v cargo >/dev/null 2>&1; then
  echo "Error: cargo not found. Install Rust via https://rustup.rs" >&2
  exit 1
fi
if ! command -v npm >/dev/null 2>&1; then
  echo "Error: npm not found. Node.js 22+ is required for the frontend build." >&2
  exit 1
fi

echo "==> Building frontend"
(cd frontend && npm ci && npm run build)

echo "==> Building du-server"
# Pinokio/conda shells export CC and CFLAGS with -O2. aws-lc-sys compiles
# jitterentropy with a forced -O0, and the extra -O2 makes it fail with:
#   "The CPU Jitter random number generator must not be compiled with optimizations"
# Build with the system compiler and clean flags instead.
env -u CC -u CXX -u CFLAGS -u CXXFLAGS -u CPPFLAGS -u LDFLAGS -u CPATH -u C_INCLUDE_PATH \
  cargo build --release -p du-server

echo "==> Done: $ROOT_DIR/target/release/du-server"
