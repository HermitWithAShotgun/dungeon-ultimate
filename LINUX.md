# Linux port (work in progress)

This branch tracks the native Linux port of Dungeon Ultimate. The Windows Tauri
desktop shell is intentionally not used: the Rust `du-server` binary serves the
same React UI and the complete REST/SSE + MCP API on loopback.

## Status

- [x] Headless `du-server` builds and runs on Ubuntu (Rust 1.100, Node 24).
- [x] Frontend builds with `npm ci && npm run build`.
- [x] `/api/health` returns `ok: true`; UI served at `http://127.0.0.1:8795`.
- [ ] Local GPU engines (llama.cpp, stable-diffusion.cpp, Higgs TTS, transcribe.cpp) still use Windows binaries from the upstream download manifest.
- [ ] Tauri Linux desktop shell (optional; browser UI works).

## Requirements

- Rust (rustup stable), Node.js 22+ with npm.
- For full local GPU mode later: NVIDIA driver + CUDA 12.8 toolkit, cmake.
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

- `DU_ROOT` — data/models/tools directory (default: repo `data/`).
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

The app downloads its model weights itself from the **What to download** panel;
no manual model files are required.

## Next steps

1. Linux llama.cpp CUDA binary for the bundled narrator (`setup.rs:223-224`).
2. Linux stable-diffusion.cpp `.so` plus platform-aware FFI names (`du-image`).
3. Linux speech-to-text (transcribe.cpp or a faster-whisper shim).
4. Local narration audio remains blocked upstream: the Higgs engine is only
   published as a Windows DLL (`setup.rs:244`). Cloud TTS is the workaround.
