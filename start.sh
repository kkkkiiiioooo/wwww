#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

install_node() {
  echo "Instalando Node.js LTS..."
  sudo apt-get update
  sudo apt-get install -y curl ca-certificates gnupg
  curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
  sudo apt-get install -y nodejs
}

if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
  install_node
fi

if [ ! -d node_modules ]; then
  echo "[1/2] Instalando dependencias..."
  npm install
else
  echo "[1/2] Dependencias ja presentes."
fi

echo "[2/2] Iniciando servidor..."

LOG_FILE="$(mktemp)"
cleanup() {
  if [ -n "${TAIL_PID:-}" ] && kill -0 "$TAIL_PID" 2>/dev/null; then
    kill "$TAIL_PID" 2>/dev/null || true
  fi
  if [ -n "${APP_PID:-}" ] && kill -0 "$APP_PID" 2>/dev/null; then
    kill "$APP_PID" 2>/dev/null || true
  fi
  rm -f "$LOG_FILE"
}
trap cleanup EXIT INT TERM

npm start >"$LOG_FILE" 2>&1 &
APP_PID=$!
tail -n +1 -f "$LOG_FILE" &
TAIL_PID=$!

URL=""
for _ in $(seq 1 60); do
  if grep -q 'http://IP:' "$LOG_FILE"; then
    URL="$(grep -m1 -o 'http://IP:[^[:space:]]*' "$LOG_FILE" | sed 's#http://IP:#http://127.0.0.1:#')"
    break
  fi
  sleep 1
done

if [ -n "$URL" ]; then
  echo
  echo "Abrindo automaticamente no navegador..."
  if [ -n "${browser:-}" ]; then
    TOKEN="" nohup "${browser}" "$URL" >/dev/null 2>&1 &
  elif [ -n "${BROWSER:-}" ]; then
    TOKEN="" nohup "${BROWSER}" "$URL" >/dev/null 2>&1 &
  else
    TOKEN="" nohup xdg-open "$URL" >/dev/null 2>&1 &
  fi
  echo "$URL"
  echo
fi

wait "$APP_PID"
