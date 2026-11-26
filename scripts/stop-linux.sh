#!/usr/bin/env bash
# Stop du-server and any llama-server it spawned.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DATA_DIR="${DU_ROOT:-$(dirname "$ROOT_DIR")/data}"
PIDFILE="$DATA_DIR/du-server.pid"

if [[ ! -f "$PIDFILE" ]]; then
  echo "No PID file at $PIDFILE; du-server is not running via run-linux.sh"
  exit 0
fi

PID="$(cat "$PIDFILE")"
if kill -0 "$PID" 2>/dev/null; then
  echo "Stopping du-server PID $PID and its process group"
  kill -TERM -"$PID" 2>/dev/null || kill -TERM "$PID" 2>/dev/null || true
else
  echo "Stale PID file (PID $PID not running)"
fi
rm -f "$PIDFILE"
