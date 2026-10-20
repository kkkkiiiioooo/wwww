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
URL="http://${IP}:${PORT}/?t=${TOKEN}"
BROWSER_CMD="${BROWSER:-${browser:-}}"

if [ ! -d node_modules ]; then
  echo "[1/2] Instalando dependencias..."
  npm install
else
  echo "[1/2] Dependencias ja presentes."
fi

if [ -n "$BROWSER_CMD" ]; then
  (
    for _ in $(seq 1 60); do
      if python3 - "$PORT" <<'PY'
import socket
import sys
s = socket.socket()
s.settimeout(0.2)
ok = s.connect_ex(("127.0.0.1", int(sys.argv[1]))) == 0
s.close()
raise SystemExit(0 if ok else 1)
PY
      then
        nohup sh -lc '"$1" "$2"' sh "$BROWSER_CMD" "$URL" >/dev/null 2>&1 &
        exit 0
      fi
      sleep 1
    done
  ) &
fi

echo "[2/2] Iniciando servidor..."
echo ""
echo "Abra no navegador:"
echo "  $URL"
if [ -n "$BROWSER_CMD" ]; then
  echo "Abrindo automaticamente com BROWSER/browser: $BROWSER_CMD"
fi
echo ""
echo "Variaveis opcionais: PORT, HOST, TOKEN, APP_SHELL, BROWSER"
echo "Pressione Ctrl+C para parar."
echo ""

HOST="$HOST" PORT="$PORT" TOKEN="$TOKEN" SHELL="$APP_SHELL" npm start
