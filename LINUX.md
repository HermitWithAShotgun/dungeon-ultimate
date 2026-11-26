# Linux port (work in progress)

This branch tracks the native Linux port of Dungeon Ultimate. The Windows Tauri
desktop shell is intentionally not used: the Rust `du-server` binary serves the
same React UI and the complete REST/SSE + MCP API on loopback.

## Status

- [x] Headless `du-server` builds and runs on Ubuntu (Rust 1.100, Node 24).
- [x] Frontend builds with `npm ci && npm run build`.
- [x] `/api/health` returns `ok: true`; UI served at `http://127.0.0.1:8795`.
- [x] End-to-end turn verified against an external OpenAI-compatible server
  (`http://192.168.1.94:8888/v1`, model `Qwen3.8-Flash-Next`): streamed prose,
  tool calls, characters created, and an image request all completed.
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

## Next steps

1. Linux llama.cpp CUDA binary for the bundled narrator (`setup.rs:223-224`).
2. Linux stable-diffusion.cpp `.so` plus platform-aware FFI names (`du-image`).
3. Linux speech-to-text (transcribe.cpp or a faster-whisper shim).
4. Local narration audio remains blocked upstream: the Higgs engine is only
   published as a Windows DLL (`setup.rs:244`). Cloud TTS is the workaround.
