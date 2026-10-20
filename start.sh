#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

PORT="${PORT:-7681}"
HOST="${HOST:-0.0.0.0}"
APP_SHELL="${APP_SHELL:-${SHELL:-/bin/bash}}"
TOKEN="${TOKEN:-$(python3 - <<'PY'
import secrets
print(secrets.token_hex(6))
PY
)}"
IP="$(hostname -I | awk '{print $1}')"

if [ ! -d node_modules ]; then
  echo "[1/2] Instalando dependencias..."
  npm install
else
  echo "[1/2] Dependencias ja presentes."
fi

echo "[2/2] Iniciando servidor..."
echo ""
echo "Abra no navegador:"
echo "  http://${IP}:${PORT}/?t=${TOKEN}"
echo ""
echo "Variaveis opcionais: PORT, HOST, TOKEN, APP_SHELL"
echo "Pressione Ctrl+C para parar."
echo ""

HOST="$HOST" PORT="$PORT" TOKEN="$TOKEN" SHELL="$APP_SHELL" npm start
