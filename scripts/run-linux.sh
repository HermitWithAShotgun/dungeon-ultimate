#!/usr/bin/env bash
# Run the headless Dungeon Ultimate server on Linux, then open http://127.0.0.1:<PORT>.
# du-server spawns llama-server lazily on the first text turn. This launcher keeps
# both in one process group so stopping the app always stops the model too.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DATA_DIR="${DU_ROOT:-$ROOT_DIR/data}"
PORT="${DU_PORT:-8795}"
PIDFILE="$DATA_DIR/du-server.pid"

command -v setsid >/dev/null 2>&1 || { echo "Error: 'setsid' (util-linux) is required" >&2; exit 1; }
mkdir -p "$DATA_DIR"

if [[ ! -x "$ROOT_DIR/target/release/du-server" ]]; then
  "$ROOT_DIR/scripts/build-linux.sh"
fi

if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  echo "Error: du-server already running (PID $(cat "$PIDFILE"))" >&2
  exit 1
fi

cd "$ROOT_DIR"
echo "Dungeon Ultimate listening on http://127.0.0.1:$PORT"

cleanup() {
  if [[ -n "${SERVER_PID:-}" ]]; then
    # Negative PID kills the whole group: du-server plus any llama-server child.
    kill -TERM -"$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
  rm -f "$PIDFILE"
}
trap cleanup EXIT HUP INT TERM

setsid env DU_ROOT="$DATA_DIR" DU_PORT="$PORT" ./target/release/du-server &
SERVER_PID=$!
echo "$SERVER_PID" > "$PIDFILE"
echo "PID $SERVER_PID (stop with ./scripts/stop-linux.sh or Ctrl-C)"

wait "$SERVER_PID"
