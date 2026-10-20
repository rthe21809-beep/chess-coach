#!/usr/bin/env bash
set -euo pipefail
ROOT="(dirname "0")/.." && pwd)"
cd "ROOT"
if [ ! -d backend/.venv ]; then python3 -m venv backend/.venv; fi
source backend/.venv/bin/activate
pip install -q -r backend/requirements.txt
(cd backend && uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload) &
BACKEND_PID=!
cleanup() { kill "BACKEND_PID" 2>/dev/null || true; }
trap cleanup EXIT INT TERM
cd frontend
[ -d node_modules ] || npm install
NEXT_TELEMETRY_DISABLED=1 npm run dev
