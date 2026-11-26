#!/usr/bin/env bash
# Run the headless Dungeon Ultimate server on Linux, then open http://127.0.0.1:<PORT>.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DATA_DIR="${DU_ROOT:-$ROOT_DIR/data}"
PORT="${DU_PORT:-8795}"

mkdir -p "$DATA_DIR"

if [[ ! -x "$ROOT_DIR/target/release/du-server" ]]; then
  "$ROOT_DIR/scripts/build-linux.sh"
fi

cd "$ROOT_DIR"
echo "Dungeon Ultimate listening on http://127.0.0.1:$PORT"
exec env DU_ROOT="$DATA_DIR" DU_PORT="$PORT" ./target/release/du-server
