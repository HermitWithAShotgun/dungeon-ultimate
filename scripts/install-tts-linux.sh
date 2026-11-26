#!/usr/bin/env bash
# Install local narration for Linux: Higgs audio engine, model and reference voices.
# Every asset is pinned by SHA-256 and interrupted downloads resume. Safe to re-run.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DU_ROOT="${DU_ROOT:-$(dirname "$ROOT_DIR")/data}"
ENGINE_DIR="$DU_ROOT/models/tts-engine"
MODEL_DIR="$DU_ROOT/models/tts"
VOICE_DIR="$DU_ROOT/models/voices"
CACHE_DIR="${DU_DOWNLOAD_CACHE:-$ROOT_DIR/.cache/tts}"
MAX_ATTEMPTS="${DU_MODEL_MAX_ATTEMPTS:-12}"

need() { command -v "$1" >/dev/null 2>&1 || { echo "Error: '$1' is required" >&2; exit 1; }; }
need curl
need sha256sum
need python3

hash_of() { sha256sum "$1" 2>/dev/null | awk '{print $1}'; }
verified() { local f="$1" sha="$2"; [[ -f "$f" ]] && [[ "$(hash_of "$f")" == "$sha" ]]; }

# curl -C - resumes a partial download. A full-length file with the wrong hash is
# discarded so the next attempt starts cleanly instead of looping forever.
fetch_verified() {
  local dir="$1" name="$2" url="$3" bytes="$4" sha="$5"
  local target="$dir/$name" part="$dir/$name.part"
  if verified "$target" "$sha"; then
    echo "==> Present: $name"
    return
  fi
  mkdir -p "$dir"
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

mkdir -p "$ENGINE_DIR" "$MODEL_DIR" "$VOICE_DIR" "$CACHE_DIR"

# 1. Engine. Upstream publishes a Linux .so beside the Windows DLL in the same release.
ENGINE_URL="https://github.com/timoncool/Higgs-Ultimate/releases/download/engine-0.2.3-turing/libaudiocpp_engine.so"
fetch_verified "$ENGINE_DIR" libaudiocpp_engine.so "$ENGINE_URL" \
  136774464 dae7b29111acf1e564f9afa541b2a4d360ba2cd6fc60eb4d5b8bdb9c04d722f6

# 2. CUDA 13 runtime beside the engine. Its RUNPATH is $ORIGIN and it links
#    libcudart.so.13 / libcublas.so.13 directly. Use the 13.2 packages: they match
#    the driver line on Ubuntu 26.04 and stay within CUDA major-version compatibility.
CUDA_REPO="https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64"
CUDART_DEB="cuda-cudart-13-2_13.2.86-1_amd64.deb"
CUBLAS_DEB="libcublas13-cuda-13_13.2.2.2-1_amd64.deb"
fetch_verified "$CACHE_DIR" "$CUDART_DEB" "$CUDA_REPO/$CUDART_DEB" \
  179474 6f5c230f993f4971eec9f91b756ba3827fa0ff1419eeba9862d02f88247c34bf
fetch_verified "$CACHE_DIR" "$CUBLAS_DEB" "$CUDA_REPO/$CUBLAS_DEB" \
  372225272 7f40c53d938fd8890bb6ed66416b5b7fbd6f6f075d7fac3d745492919a560ef0

need dpkg-deb
for deb in "$CUDART_DEB" "$CUBLAS_DEB"; do
  unpack="$CACHE_DIR/$(basename "$deb" .deb)-root"
  rm -rf "$unpack"
  mkdir -p "$unpack"
  echo "==> Extracting $deb"
  dpkg-deb -x "$CACHE_DIR/$deb" "$unpack"
  while IFS= read -r lib; do
    cp -a "$lib" "$ENGINE_DIR/$(basename "$lib")"
  done < <(find "$unpack" -type f -o -type l | grep -E '/lib(cudart|cublas|cublasLt)\.so\.13[^/]*$' || true)
done

# 3. Higgs weights and tokenizer, pinned to the revision used by upstream setup.
HF_BASE="https://huggingface.co/drbaph/Higgs-Audio-v3-Studio/resolve/c6e9db5a2062c15accc1b9bfa54d927bbdb124dc/models/higgs-q4_k_m"
fetch_verified "$MODEL_DIR" q4_k_m.gguf "$HF_BASE/q4_k_m.gguf" \
  4086922976 a6c8a9b5c8c72965865988c6ef411d32446aeb0df730f59e7bd4a3e801cea3a1
fetch_verified "$MODEL_DIR" config.json "$HF_BASE/config.json" \
  2755 2ead4442c079ee35c2123a5b197e126e18eccfc0bdb65d31c94767e75d7864d4
fetch_verified "$MODEL_DIR" chat_template.jinja "$HF_BASE/chat_template.jinja" \
  2427 44d5f08f3f72b837eaad09f13a54c1f9f4eb58d75240334548b7fd52a5437fa5
fetch_verified "$MODEL_DIR" tokenizer.json "$HF_BASE/tokenizer.json" \
  11433924 eb883de2de5adc5113f1f02b54830a0ea7cd6ef191cde65c41aceb3737d4d1c1
fetch_verified "$MODEL_DIR" tokenizer_config.json "$HF_BASE/tokenizer_config.json" \
  1937 b4d632e1239569fb1829bf0bfa3c674fa54f22c42e9cb2669d77c438d4b4e02c
fetch_verified "$MODEL_DIR" higgs_audio_v2_tokenizer_config.json "$HF_BASE/higgs_audio_v2_tokenizer_config.json" \
  2251 1f96f10516c2bb59d5a127e04e659a331a50fb1684217b1492fabd1dc94def26

# 4. Reference voices. Upstream's "Пак голосов" is a flat zip of clips and optional
#    transcripts; du-server looks for models/voices/<name>.{wav,mp3,flac}(+.txt).
VOICE_ZIP="voice-pack.zip"
fetch_verified "$CACHE_DIR" "$VOICE_ZIP" \
  "https://huggingface.co/datasets/nerualdreming/VibeVoice/resolve/5c884b3cbdc932c39a5167951c4072120e1a0310/$VOICE_ZIP" \
  104685334 682e73c189dbe9bc66fc35bc8fb29438641155957a917a7cc914f2f176a65264

python3 - "$CACHE_DIR/$VOICE_ZIP" "$VOICE_DIR" <<'PY'
import os, sys, zipfile
archive, target = sys.argv[1], sys.argv[2]
os.makedirs(target, exist_ok=True)
with zipfile.ZipFile(archive) as z:
    for info in z.infolist():
        name = os.path.basename(info.filename.replace("\\", "/"))
        if not name:
            continue
        dest = os.path.join(target, name)
        if os.path.exists(dest):
            continue
        with z.open(info) as src, open(dest, "wb") as out:
            out.write(src.read())
print("voices:", len([n for n in os.listdir(target) if n.lower().endswith((".wav", ".mp3", ".flac"))]))
PY

# Upstream's default story voice is "Vedushchiy", but this public voice pack has no clip
# by that name. Give the default a real narrator clip so a fresh install speaks without
# making the player pick a voice by hand. A short 16 kHz mono WAV is used because the
# server's WAV path avoids re-decoding the long MP3 on every first use.
if [[ -f "$VOICE_DIR/RU_Male_Denis_Kolesnikov.mp3" && ! -e "$VOICE_DIR/Vedushchiy.wav" ]]; then
  if command -v ffmpeg >/dev/null 2>&1; then
    ffmpeg -hide_banner -loglevel error -y \
      -i "$VOICE_DIR/RU_Male_Denis_Kolesnikov.mp3" \
      -t "${DU_TTS_REFERENCE_SECONDS:-12}" -ac 1 -ar 16000 \
      "$VOICE_DIR/Vedushchiy.wav"
  else
    fallback="$(find "$VOICE_DIR" -maxdepth 1 -type f -iname '*.wav' ! -iname '*.ref*wav' ! -iname 'Vedushchiy.wav' | head -n 1 || true)"
    [[ -n "$fallback" ]] && cp "$fallback" "$VOICE_DIR/Vedushchiy.wav"
  fi
  if [[ -f "$VOICE_DIR/RU_Male_Denis_Kolesnikov.txt" && ! -e "$VOICE_DIR/Vedushchiy.txt" ]]; then
    cp "$VOICE_DIR/RU_Male_Denis_Kolesnikov.txt" "$VOICE_DIR/Vedushchiy.txt"
  fi
  echo "==> Default voice alias: Vedushchiy -> RU_Male_Denis_Kolesnikov"
fi
# An older revision of this installer wrote an MP3 alias. WAV takes priority, but remove
# the stale copy so the voice list never shows two entries for the same narrator.
rm -f "$VOICE_DIR/Vedushchiy.mp3" "$VOICE_DIR/Vedushchiy.ref12s.wav"

# The in-app "what to download" screen looks for this marker (name stem + SHA prefix).
printf '%s\n' "https://huggingface.co/datasets/nerualdreming/VibeVoice/resolve/5c884b3cbdc932c39a5167951c4072120e1a0310/voice-pack.zip" \
  > "$VOICE_DIR/.voice-pack-682e73c189db.installed"

echo "==> Engine:"
ls -1 "$ENGINE_DIR" | head -20
echo "==> Done. Rebuild du-server, restart, and select a voice in chat settings."
