#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

command -v termux-wake-lock >/dev/null 2>&1 && termux-wake-lock || true

if [ ! -d backend/.venv ]; then python -m venv backend/.venv; fi
source backend/.venv/bin/activate
pip install -q --upgrade pip
pip install -q -r backend/requirements.txt

if [ ! -f backend/.env ]; then
  echo "WARN: backend/.env missing -- copying example"
  cp backend/.env.example backend/.env
fi

(cd backend && uvicorn app.main:app --host 127.0.0.1 --port 8000) &
BACKEND_PID=$!
cleanup() {
  kill "$BACKEND_PID" 2>/dev/null || true
  command -v termux-wake-unlock >/dev/null 2>&1 && termux-wake-unlock || true
}
trap cleanup EXIT INT TERM

sleep 1
echo "-> backend: http://127.0.0.1:8000/api/system/health"

cd frontend
[ -d node_modules ] || npm install
NEXT_TELEMETRY_DISABLED=1 npm run dev
