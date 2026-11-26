// This fork is the native Linux build. Upstream's setup manifest and model
// pickers still list Windows binaries and Ollama model ids; leaving them visible
// lets a player "download" a DLL/EXE or pick a GGUF the server never loads.
//
// Keep the allow/deny decision in one place so the panels cannot drift apart.
export const PINNED_LINUX_BUILD = true;

export const LINUX_UNSUPPORTED_SETUP_IDS: ReadonlySet<string> = new Set([
  // Windows engine bundles: the Linux scripts install .so files in their place.
  "image-engine",
  "narrator-engine",
  // Local speech recognition upstream is Windows-only (transcribe.cpp / faster-whisper).
  "asr",
  "asr-ultra",
  "asr-gpu",
  "whisper-cuda",
  "whisper-tiny",
  "whisper-base",
  "whisper-small",
  "whisper-medium",
  "whisper-large-v3",
  "whisper-large-v3-turbo",
]);

export const LINUX_PINNED_LOCAL_TEXT_MODEL = "gemma4:12b-it-qat";

export function linuxCompatibleComponents<T extends { id: string }>(items: T[]): T[] {
  if (!PINNED_LINUX_BUILD) {
    return items;
  }
  return items.filter((item) => !LINUX_UNSUPPORTED_SETUP_IDS.has(item.id));
}
