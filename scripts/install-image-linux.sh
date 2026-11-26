#!/usr/bin/env bash
# Install the local image-generation engine and Krea-2 Turbo weights for Linux.
# Every file is pinned by SHA-256 and downloads resume after network drops.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DU_ROOT="${DU_ROOT:-$(dirname "$ROOT_DIR")/data}"
MODEL_DIR="$DU_ROOT/models/image"
MAX_ATTEMPTS="${DU_MODEL_MAX_ATTEMPTS:-12}"
WITH_LORA="${DU_IMAGE_LORA:-1}"

need() { command -v "$1" >/dev/null 2>&1 || { echo "Error: '$1' is required" >&2; exit 1; }; }
need curl
need sha256sum

hash_of() { sha256sum "$1" 2>/dev/null | awk '{print $1}'; }
verified() { local f="$1" sha="$2"; [[ -f "$f" ]] && [[ "$(hash_of "$f")" == "$sha" ]]; }

# curl -C - resumes a partial download. A file that reached full length but has
# the wrong hash is discarded so the next attempt starts cleanly.
fetch_verified() {
  local name="$1" url="$2" bytes="$3" sha="$4"
  local target="$MODEL_DIR/$name" part="$MODEL_DIR/$name.part"
  if verified "$target" "$sha"; then
    echo "==> Present: $name"
    return
  fi
  mkdir -p "$MODEL_DIR"
  local attempt=1
  until verified "$part" "$sha"; do
    if (( attempt > MAX_ATTEMPTS )); then
      echo "Error: could not verify $name after $MAX_ATTEMPTS attempts" >&2
      exit 1
    fi
    if [[ -f "$part" ]]; then
      local size
      size="$(stat -c%s "$part" 2>/dev/null || echo 0)"
      if (( size > bytes )) || { (( size == bytes )) && [[ "$(hash_of "$part")" != "$sha" ]]; }; then
        echo "==> Discarding bad partial: $name ($size bytes)"
        rm -f "$part"
      fi
    fi
    echo "==> Downloading $name — attempt $attempt/$MAX_ATTEMPTS ($(stat -c%s "$part" 2>/dev/null || echo 0)/$bytes bytes)"
    curl -fL -C - --retry 5 --retry-delay 5 --retry-all-errors \
      --connect-timeout 30 --max-time 3600 -o "$part" "$url" || true
    attempt=$((attempt + 1))
    if ! verified "$part" "$sha"; then
      echo "==> $name incomplete; retrying in 15s"
      sleep 15
    fi
  done
  mv -f "$part" "$target"
  echo "==> Verified: $name"
}

if [[ "${DU_IMAGE_SKIP_ENGINE:-0}" != "1" ]]; then
  "$ROOT_DIR/scripts/build-image-linux.sh"
fi

BASE="https://huggingface.co"
fetch_verified "krea2-turbo-Q4_K_M.gguf" \
  "$BASE/realrebelai/KREA-2_GGUFs/resolve/9721c3ec932c43dff6dbb5793a816d9ad105277f/TURBO/Krea-2-Turbo-Q4_K_M.gguf" \
  7216993376 273a98be1afe317bc7228403b6434647eaf866cebe6aff1980c401b950473807
fetch_verified "qwen3-vl-4b-abliterated-Q4_K_M.gguf" \
  "$BASE/noctrex/Huihui-Qwen3-VL-4B-Instruct-abliterated-GGUF/resolve/0e204140ef43727fb4ee4d4bbd88c948c64719df/Huihui-Qwen3-VL-4B-Instruct-abliterated-Q4_K_M.gguf" \
  2497282240 9789bbc02e77bf3b9cfe7b54a6b212a1e8904ffc77df61243353a05fcb203167
fetch_verified "wan_2.1_vae.safetensors" \
  "$BASE/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/123acf1cc74bccbb9bfff8ac1ee72edc08c2341d/split_files/vae/wan_2.1_vae.safetensors" \
  253815318 2fc39d31359a4b0a64f55876d8ff7fa8d780956ae2cb13463b0223e15148976b
if [[ "$WITH_LORA" == "1" ]]; then
  fetch_verified "krea2-identity-edit-r128.safetensors" \
    "$BASE/conradlocke/krea2-identity-edit/resolve/89e9e7a09ee2e5c9331e952063d79b1b8a703280/krea2_identity_edit_v1_2_r128.safetensors" \
    914159744 f53db0bb4b081d638f196865cbc9f055379704fafb788336784fc1ccde18d825
fi

echo "Done. Rebuild du-server (du-image changed), restart with ./scripts/run-linux.sh, then enable images in chat settings."
