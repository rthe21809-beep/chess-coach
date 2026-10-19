# Chess Coach

Local-first chess app: **Next.js + React + TypeScript** frontend, **FastAPI + Stockfish** backend, **Groq LLM** coach. Runs entirely on your phone (Termux) or laptop.

- Animated board (react-chessboard), eval bar, arrows, sounds
- Adjustable **Stockfish** bot (Elo 1320–3190, depth, threads, hash) + optional **Maia** (lc0)
- **Ultra-deep analysis**: multi-PV lines, cloud fallback (Lichess / chess-api.com)
- **Full game review**: per-move accuracy, ACPL, classification (blunder/mistake/…)
- **LLM coach** grounded in engine output — never invents moves

## Quick start (Termux)

```bash
pkg update -y && pkg install -y git python nodejs-lts stockfish
git clone https://github.com/rthe21809-beep/chess-coach.git
cd chess-coach
cp backend/.env.example backend/.env   # add GROQ_API_KEY (optional)
bash scripts/start_termux.sh
```

Open **http://127.0.0.1:3000**.

### Desktop

```
brew install stockfish   # or sudo apt install stockfish
cp backend/.env.example backend/.env
bash scripts/dev.sh
```

## Groq (free tier)

Get a key at https://console.groq.com/keys and put it in `backend/.env`:

```
GROQ_API_KEY=gsk_...
GROQ_DEFAULT_MODEL=openai/gpt-oss-120b
```

Free tier ≈ 30 rpm · 1k rpd · 200k tokens/day. Plenty for personal coaching.

**No key?** Coach falls back to a deterministic engine summary. The app still works.

## Config you can change from the UI

Engine: Stockfish/Maia, Elo, depth, think time, threads, hash, multi-PV, Maia model.
Board: square colours, animation ms, coordinates, legal-move dots, arrows, eval bar, sounds, volume.
Coach: model id, temperature, streaming, your rating, language.

All persisted in `localStorage`.

## Performance on phone

| ↕▾ | phone-friendly ↕▾ | strong ↕▾ |
|---|---|---|
| −Threads | 1 | 2–4 |
| −Hash | 16–64 MB | 256–512 MB |
| Depth | 12–14 | 18–22 |
| Think time | 300–800 ms | 1.5–3 s |
⚙

Modern phone reaches **3000+ Elo** with 2 threads and a couple of seconds per move.

## Repo layout

```
chess-coach/
├── backend/         FastAPI + Stockfish manager + Groq coach
├── frontend/        Next.js 14 app
├── scripts/         dev.sh, start_termux.sh, push.sh
└── docs/            API, Maia, Troubleshooting
```

MIT licensed.

</BDS:create_file>

<BDS:create_file fileName="chess-coach/.gitignore">

```gitignore
node_modules/
.pnp
.pnp.js
.next/
out/
build/
dist/
__pycache__/
*.py[cod]
.venv/
venv/
*.egg-info/
.pytest_cache/
.env
.env.local
.env.*.local
backend/.env
*.log
.DS_Store
Thumbs.db
coverage/
.idea/
.vscode/
*.tsbuildinfo

