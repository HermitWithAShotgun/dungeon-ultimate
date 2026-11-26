# Linux port (NVIDIA/CUDA only)

This branch tracks the native Linux port of Dungeon Ultimate. The Windows Tauri
desktop shell is intentionally not used: the Rust `du-server` binary serves the
same React UI and the complete REST/SSE + MCP API on loopback.

**Hardware support:** the local narrator and local image engines are built for
NVIDIA CUDA 12.8; the Higgs narration engine is built for CUDA 13. The required
CUDA 13 runtime libraries are installed privately beside the engine, so both
major versions coexist in one process. AMD/ROCm, Vulkan, and CPU image generation
are not supported by this port. Cloud stages work independently of the GPU.

## Status

- [x] Headless `du-server` builds and runs on Ubuntu (Rust 1.100, Node 24).
- [x] Frontend builds with `npm ci && npm run build`.
- [x] `/api/health` returns `ok: true`; UI served at `http://127.0.0.1:8795`.
- [x] End-to-end turn verified against an external OpenAI-compatible server
  (`http://192.168.1.94:8888/v1`, model `Qwen3.8-Flash-Next`): streamed prose,
  tool calls, characters created, and an image request all completed.
- [x] Local narrator: pinned llama.cpp b11557 Ubuntu CUDA 12.8 + Gemma 4 12B uncensored GGUF, started lazily by `du-server`.
- [x] Local image weights downloaded and SHA-256 verified (Krea-2 Turbo, Qwen3-VL-4B, Wan VAE, identity-edit LoRA).
- [x] Local stable-diffusion.cpp CUDA engine build and verified image turn (~17 s for a 1024×768 fast frame on an RTX 5090 Laptop).
- [x] Local Higgs narration audio: upstream Linux `.so` engine + CUDA 13 runtime, voice pack, and pinned weights; verified through `/api/tts`.
- [ ] transcribe.cpp speech recognition remains Windows-only upstream (cloud ASR / no ASR is the workaround).
- [x] Pinokio launcher at `PINOKIO_HOME/api/dungeon-ultimate-linux` (Install / Start / Update / Reset).
- [ ] Tauri Linux desktop shell (optional; browser UI works).

## Requirements

- Rust (rustup stable), Node.js 22+ with npm.
- NVIDIA driver + CUDA 12.8 toolkit (provided by the Pinokio environment) and cmake.
- No sudo needed for the headless build.

## Build and run

```bash
./scripts/build-linux.sh
./scripts/run-linux.sh
# open http://127.0.0.1:8795
```

If your shell exports conda/Pinokio `CC` and `CFLAGS`, the build script clears
them for the `cargo` invocation. This is required because `aws-lc-sys` compiles
its jitterentropy source with `-O0`, and an inherited `-O2` makes it fail.

Environment variables:

- `DU_ROOT` — data/models/tools directory (default: `dungeon-ultimate-linux/data`, beside the repo).
- `DU_PORT` — HTTP port (default: `8795`).

The server binds only to `127.0.0.1`, and its Host/Origin guard accepts only
loopback names. For access from another machine you need a reverse proxy that
preserves `Host: localhost`, or a patch to `crates/du-server/src/lib.rs` and
`crates/du-server/src/guard.rs`.

## Playing without the Windows engines

The narrator can use any OpenAI-compatible endpoint (llama.cpp, LM Studio,
vLLM, Ollama, Unsloth). In the story settings choose **Local server** and set
`custom_base_url`, for example `http://192.168.1.94:8888/v1`. This path was
fixed upstream in v0.13.4 (issue #7). Image narration audio can be switched to
OpenRouter in `DU_ROOT/models/runtime.json`, or disabled.

### Verified custom-endpoint configuration

Create a chat with these settings (the server reads them from the chat row, so
the `/api/story` body only needs `chatId` and `input`):

```json
{
  "textProvider": "custom",
  "customBaseUrl": "http://192.168.1.94:8888/v1",
  "customModel": "Qwen3.8-Flash-Next",
  "language": "en",
  "imageGenerationEnabled": false,
  "autoImages": false,
  "autoplay": false
}
```

The narrator then uses the external server for **all** passes in a turn: prose
streaming, the JSON-schema structured passes (game mechanics, tool calls, image
request), and follow-up assists such as `/api/actions` and `/api/suggest`. The
endpoint must accept `response_format.type =
"json_schema"` with `strict: true` — `Qwen3.8-Flash-Next` does, using its exact
grammar mode. Reasoning is returned as `reasoning_content`, so the visible
`content` stays clean JSON; structured sampling allows 3072 tokens, which is
ample.

### The bundled uncensored model

Upstream's own narrator model is **Gemma 4 12B IT uncensored, Q4_K_M**:
`zaakirio/gemma-4-12b-it-uncensored-GGUF` → `gemma-4-12b-it-uncensored-Q4_K_M.gguf`
(7.38 GB, SHA-256 `b2e1db5f81b9f0ce489f99fd448bbf4ea8ea719e8d28c05aaa5774afc5def76c`).
`du-server` expects it at `DU_ROOT/models/text/narrator.gguf` and launches the
bundled `llama-server` on a free loopback port with `-ngl`, `-c`, `--flash-attn
on`, `--parallel 1`, and `--jinja` (`crates/du-llm/src/server.rs:98-129`).

It can be used on Linux in two ways:

1. **Already possible today:** run any Linux `llama-server` with that GGUF and
   point the chat's `customBaseUrl` at it (including `http://127.0.0.1:8080/v1`,
   which is the frontend's static fallback model path). No code change needed.
2. **Proper port (Phase 2):** build llama.cpp b11557 for Linux CUDA and place
   `llama-server` in `DU_ROOT/tools/llama/`, or set `DU_LLAMA_BIN`. The resolver
   already looks for the extension-less name off Windows. Then choose
   `textProvider: "local"` and let `du-server` own the model, GPU slot, and
   cleanup.

The app downloads the GGUF itself from the **What to download** panel; no
manual model files are required.

## Local narrator (offline)

```bash
./scripts/install-narrator-linux.sh   # pinned llama.cpp CUDA 12.8 + Gemma 4 12B uncensored GGUF
./scripts/run-linux.sh                # starts du-server; llama-server starts on first text turn
./scripts/stop-linux.sh               # stops du-server and its llama-server child
```

The installer verifies every download by SHA-256 and installs into `DU_ROOT`
(default: `dungeon-ultimate-linux/data`, beside the repo). The narrated model is
**not running all the time**:

- `du-server` starts `llama-server` lazily on the first text request
  (`gpu.rs:137-169`) and holds it only for the session.
- `run-linux.sh` puts `du-server` and its children in one process group; Ctrl-C,
  `tmux kill-session`, or `stop-linux.sh` terminates both.
- `LlamaServer::drop()` stops the child on graceful exit
  (`du-llm/src/server.rs:215-219`).
- If the app is SIGKILLed before cleanup, `du_llm::kill_orphans()` removes any
  leftover `llama-server` from this `DU_ROOT` on the next start
  (`lib.rs:145-148`, `server.rs:227-251`).

To use it in a story, choose **Local** as the text provider (or keep `custom`
and point `customBaseUrl` at the spawned server). The local path needs no
OpenRouter key and no LAN endpoint.

## Local image generation (offline)

```bash
./scripts/install-image-linux.sh   # pinned sd.cpp CUDA engine + Krea-2 Turbo weights
./scripts/run-linux.sh             # starts du-server; sd.cpp loads on first image
./scripts/stop-linux.sh            # stops du-server and its model children
```

The upstream release for the pinned sd.cpp commit has no Linux CUDA binary, so
`build-image-linux.sh` builds the exact pinned commit (`1b0ba10`) from source
with `SD_CUDA=ON`, dynamic ggml backends, and sm_80–120 kernels. It installs
`libstable-diffusion.so`, `libggml.so`, `libggml-cuda.so`, and the CUDA runtime
libraries reused from the narrator bundle into `DU_ROOT/models/runtime/sd/`.
The libraries are built with `RPATH=$ORIGIN`, and `du-image` registers backends
from that same directory by absolute path, so no global `LD_LIBRARY_PATH` is
needed. This matters: llama.cpp b11557 ships ggml 0.26 while the pinned sd.cpp
ships ggml 0.25, and prepending the image directory to `LD_LIBRARY_PATH` would
make `llama-server` load the wrong ggml and fail to find any CUDA backend.

Weights are pinned by SHA-256 and resume after network drops:

- `krea2-turbo-Q4_K_M.gguf` (diffusion model)
- `qwen3-vl-4b-abliterated-Q4_K_M.gguf` (conditioning encoder)
- `wan_2.1_vae.safetensors` (VAE)
- `krea2-identity-edit-r128.safetensors` (identity-edit LoRA)

`du-server` releases the narrator from VRAM before `generate_image` loads the
image weights, then drops the sd.cpp context immediately after rendering so the
next narration turn can use the card (`gpu.rs:233-262`).

Verified sequence: local story turn starts `llama-server` (~8.8 GB VRAM), an
image request stops it and renders a PNG (~17 s), and the following story turn
starts a fresh `llama-server` and streams prose with no errors. The two engines
ship incompatible ggml versions (llama.cpp 0.26 vs. sd.cpp 0.25), so neither the
launcher nor the FFI may put the sd.cpp directory into `LD_LIBRARY_PATH`; the
sd.cpp libraries use `RPATH=$ORIGIN` and backends load from absolute paths.

## Local narration audio (offline)

```bash
./scripts/install-tts-linux.sh   # engine, CUDA 13 runtime, Higgs weights, voices
./scripts/run-linux.sh           # starts du-server; the voice engine loads on first speech
```

The installer resumes interrupted downloads and verifies every asset by SHA-256:

- `libaudiocpp_engine.so` from upstream release `engine-0.2.3-turing` (glibc ≥ 2.34, CUDA 13.3 build).
- `libcudart.so.13`, `libcublas.so.13`, `libcublasLt.so.13` from pinned NVIDIA CUDA 13.2 Ubuntu packages, extracted privately into `DU_ROOT/models/tts-engine/` with `dpkg-deb -x`. No sudo and no system-wide library changes.
- Higgs `q4_k_m` weights, tokenizer, and chat template under `DU_ROOT/models/tts/`.
- The upstream voice pack, unpacked flat into `DU_ROOT/models/voices/`.

The engine is loaded through the same `libloading` FFI as on Windows; `gpu.rs`
and `tts.rs` pick `libaudiocpp_engine.so` on Linux and `audiocpp_engine.dll` on
Windows. The in-app **What to download** list is platform-aware too: it no
longer asks Linux players for the Windows DLL and its CUDA 13 wheels.

Upstream's default story voice is `Vedushchiy`, but the public voice pack has no
clip with that name. The installer creates a short 16 kHz mono `Vedushchiy.wav`
from a neutral Russian male narrator clip (plus its transcript), so a fresh
install speaks without asking the player to pick a voice first. Any other clip
in the pack can still be selected in the story settings.

Like the narrator and image engines, the voice engine occupies the GPU only for
as long as it is needed: loading it stops `llama-server`, and an image turn drops
the voice engine before the sd.cpp weights come in.

Cloud narration is already an opt-in in **Settings → Engines → Narration →
Cloud** (OpenRouter or Google, with model and voice selection). Local Higgs stays
the default; selecting Cloud routes `/api/tts` and story audio to the provider,
and an unset key produces an explicit error instead of silently falling back to
the GPU.

Verified sequence: `/api/tts` returned a playable 24 kHz mono WAV, an image turn
released the voice engine and rendered a PNG, and the following `/api/tts` call
synthesized another clip with no orphan model processes.

## Pinokio launcher

The launcher lives beside the `app/` and `data/` folders at
`PINOKIO_HOME/api/dungeon-ultimate-linux`:

- `install.js` — declares the `ai` bundle, then runs `build-linux.sh` plus the three Linux installers (narrator, image, narration).
- `start.js` — daemonized; asks Pinokio for a free loopback port, starts
  `scripts/run-linux.sh`, captures the printed URL, and sets the `url` local so
  the menu shows **Open Web UI**.
- `update.js` / `reset.js` — pull and rebuild, or remove build outputs and
  downloaded models while keeping chats.
- `pinokio.js` / `pinokio.json` — dynamic menu and metadata; platform is declared
  as Linux-only.

Stopping the script from Pinokio terminates the shell and the process group, so
`llama-server` and any image engine child go down with the app.

## Next steps

1. ~~Linux llama.cpp CUDA binary for the bundled narrator~~ done via the pinned
   b11557 Ubuntu CUDA 12.8 release and `install-narrator-linux.sh`.
2. ~~Linux stable-diffusion.cpp `.so` plus platform-aware FFI names (`du-image`).~~
   Done; CUDA engine loads through FFI and a real `/api/images` turn renders a PNG.
3. ~~Local narration audio~~ done via upstream's Linux `libaudiocpp_engine.so`,
   pinned CUDA 13 runtime libraries, Higgs weights, and the voice pack.
4. Linux speech-to-text (transcribe.cpp or a faster-whisper shim).
