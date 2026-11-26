#!/usr/bin/env bash
# Install the pinned Linux llama.cpp CUDA engine and the uncensored narrator GGUF.
# Everything lands under DU_ROOT (default: repo data/). Safe to re-run.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DU_ROOT="${DU_ROOT:-$(dirname "$ROOT_DIR")/data}"
TOOLS_DIR="$DU_ROOT/tools/llama"
MODEL_DIR="$DU_ROOT/models/text"
CACHE_DIR="${DU_DOWNLOAD_CACHE:-$ROOT_DIR/.cache/llama}"

LLAMA_REV="b11557"
LLAMA_ARCHIVE="llama-b11557-bin-ubuntu-cuda-12.8-x64.tar.gz"
LLAMA_SHA="7f7bc3128c4975a8e0e5e8463d352c27f0629a3e554d84624e3b88b060b3c3d4"
CUDART_ARCHIVE="cudart-llama-b11557-bin-ubuntu-cuda-12.8-x64.tar.gz"
CUDART_SHA="5450b9bda62297566c315ba3add07ddcdf6cb332070d44dbb04c540881dd3f1c"
RELEASE_BASE="https://github.com/ggml-org/llama.cpp/releases/download/$LLAMA_REV"

MODEL_REPO="zaakirio/gemma-4-12b-it-uncensored-GGUF"
MODEL_REV="32880562ac43cb589a85afb864309fdcaf486fae"
MODEL_FILE="gemma-4-12b-it-uncensored-Q4_K_M.gguf"
MODEL_SHA="b2e1db5f81b9f0ce489f99fd448bbf4ea8ea719e8d28c05aaa5774afc5def76c"

need() {
  command -v "$1" >/dev/null 2>&1 || { echo "Error: '$1' is required" >&2; exit 1; }
}
need curl
need tar
need sha256sum
need hf

verified() {
  local file="$1" expected="$2" actual
  [[ -f "$file" ]] || return 1
  actual="$(sha256sum "$file" | awk '{print $1}')"
  [[ "$actual" == "$expected" ]]
}

fetch_verified() {
  local name="$1" sha="$2" path="$CACHE_DIR/$1"
  if verified "$path" "$sha"; then
    echo "==> Cached: $name"
    return
  fi
  echo "==> Downloading $name"
  curl -fL --retry 3 --retry-delay 2 -o "$path.part" "$RELEASE_BASE/$name"
  mv "$path.part" "$path"
  verified "$path" "$sha" || { echo "Error: checksum mismatch for $name" >&2; exit 1; }
}

mkdir -p "$TOOLS_DIR" "$MODEL_DIR" "$CACHE_DIR"

# 1. Engine: llama-server + ggml CUDA backend + CUDA 12.8 runtime libs.
if [[ -x "$TOOLS_DIR/llama-server" ]]; then
  echo "==> Engine already present: $TOOLS_DIR/llama-server"
else
  fetch_verified "$LLAMA_ARCHIVE" "$LLAMA_SHA"
  fetch_verified "$CUDART_ARCHIVE" "$CUDART_SHA"
  echo "==> Extracting engine into $TOOLS_DIR"
  tar xzf "$CACHE_DIR/$LLAMA_ARCHIVE" -C "$TOOLS_DIR" --strip-components=1
  tar xzf "$CACHE_DIR/$CUDART_ARCHIVE" -C "$TOOLS_DIR" --strip-components=1
fi

# 2. Narrator weights. du-server expects models/text/narrator.gguf; keep the
#    versioned HF filename and link to it so re-runs can verify the download.
TARGET="$MODEL_DIR/narrator.gguf"
SOURCE="$MODEL_DIR/$MODEL_FILE"
if verified "$TARGET" "$MODEL_SHA"; then
  echo "==> Narrator model already present: $TARGET"
else
  echo "==> Downloading narrator GGUF (~7.4 GB): $MODEL_FILE"
  # Use the classic HTTP backend: the default Xet backend can fail with transient
  # CDN reconstruction errors. Retry so a dropped connection resumes the partial
  # file instead of losing progress. Every attempt is checksum-verified at the end.
  if [[ -n "${HF_TOKEN_PATH:-}" && -s "$HF_TOKEN_PATH" ]]; then
    export HF_TOKEN="$(cat "$HF_TOKEN_PATH")"
  fi
  ATTEMPT=1
  MAX_ATTEMPTS="${DU_MODEL_MAX_ATTEMPTS:-10}"
  until verified "$SOURCE" "$MODEL_SHA"; do
    if (( ATTEMPT > MAX_ATTEMPTS )); then
      echo "Error: could not download/verify $MODEL_FILE after $MAX_ATTEMPTS attempts" >&2
      exit 1
    fi
    echo "==> Download attempt $ATTEMPT/$MAX_ATTEMPTS"
    HF_HUB_DISABLE_XET=1 hf download "$MODEL_REPO" "$MODEL_FILE" \
      --revision "$MODEL_REV" --local-dir "$MODEL_DIR" || true
    ATTEMPT=$((ATTEMPT + 1))
    if ! verified "$SOURCE" "$MODEL_SHA"; then
      echo "==> Download incomplete/failed; retrying in 15s"
      sleep 15
    fi
  done
  ln -sfn "$MODEL_FILE" "$TARGET"
fi

"$TOOLS_DIR/llama-server" --version | head -2
echo "Done. Start du-server with ./scripts/run-linux.sh; it spawns llama-server on the first text request."
