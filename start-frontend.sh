#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/frontend"

if command -v npm.cmd >/dev/null 2>&1; then
  exec npm.cmd start
fi

if command -v npm >/dev/null 2>&1; then
  exec npm start
fi

echo "No se encontro npm o npm.cmd en el PATH." >&2
echo "Instala Node.js y vuelve a intentarlo." >&2
exit 1
