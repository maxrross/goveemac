#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${1:-$ROOT_DIR/dist/Govee Mac.app}"
BIN_DIR="${2:-$HOME/.local/bin}"
CLI_PATH="$APP_PATH/Contents/MacOS/govee"
[[ -x "$CLI_PATH" ]] || { echo "Build or install Govee Mac first." >&2; exit 1; }
mkdir -p "$BIN_DIR"
if [[ -e "$BIN_DIR/govee" && ! -L "$BIN_DIR/govee" ]]; then
  echo "A different executable already exists at $BIN_DIR/govee. Choose another directory." >&2; exit 1
fi
ln -sfn "$CLI_PATH" "$BIN_DIR/govee"
echo "Installed $BIN_DIR/govee. Add this directory to PATH if needed."
