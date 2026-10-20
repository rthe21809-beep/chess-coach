#!/usr/bin/env bash
# bootstrap-10.sh — ReviewPanel + page.tsx. Final script; app runs after this.
set -euo pipefail

[ -f frontend/src/components/CoachPanel.tsx ] || { echo "ERROR: run bootstrap-09 first"; exit 1; }

echo "→ bootstrap-10: ReviewPanel + page.tsx"

cat > frontend/src/components/ReviewPanel.tsx << 'TSXEOF'
"use client";

import { useState } from "react";
import { streamReview } from "@/lib/api";
import { useSettings } from "@/lib/store";
import { classifyColor, classifyIcon, formatAccuracy } from "@/lib/format";
import type { GameReview } from "@/lib/types";

interface ReviewPanelProps {
  pgn: string;
}

export default function ReviewPanel({ pgn }: ReviewPanelProps) {
  const { settings } = useSettings();
  const [review, setReview] = useState<GameReview | null>(null);
  const [progress, setProgress] = useState<{ done: number; total: number } | null>(
    null
  );
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const start = async () => {
    if (!pgn || busy) return;
    setBusy(true);
    setError(null);
    setReview(null);
    setProgress(null);
    try {
      for await (const ev of streamReview(
        pgn,
        settings.engine,
        Math.min(12, settings.engine.depth)
      )) {
        if (ev.kind === "progress") setProgress(ev.data);
        else if (ev.kind === "result") setReview(ev.data);
        else if (ev.kind === "error") {
          setError(ev.message);
          break;
        }
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="space-y-3 p-3 text-sm">
      <button
        onClick={start}
        disabled={busy || !pgn}
        className="w-full rounded-md bg-[#4d6bfe] py-2 font-medium disabled:opacity-40"
      >
        {busy ? "Reviewing…" : "Review this game"}
      </button>

      {!pgn && (
        <div className="text-xs text-[#99a2b3]">Play a game first.</div>
      )}

      {progress && busy && (
        <div className="rounded-md border border-[#2a303b] bg-[#161a21] p-2 text-xs">
          <div className="flex justify-between">
            <span>Analyzing</span>
            <span className="font-mono">
              {progress.done}/{progress.total}
            </span>
          </div>
          <div className="mt-1 h-1.5 overflow-hidden rounded bg-[#1d222b]">
            <div
              className="h-full bg-[#6ea8fe] transition-[width]"
              style={{
                width: `${(progress.done / Math.max(1, progress.total)) * 100}%`,
              }}
            />
          </div>
        </div>
      )}

      {error && (
        <div className="rounded-md border border-red-500/30 bg-red-500/5 p-2 text-xs text-red-300">
          {error}
        </div>
      )}

      {review && (
        <div className="space-y-3">
          <div className="grid grid-cols-2 gap-2">
            {(["white", "black"] as const).map((side) => {
              const acc =
                side === "white" ? review.whiteAccuracy : review.blackAccuracy;
              const acpl =
                side === "white" ? review.whiteAcpl : review.blackAcpl;
              return (
                <div
                  key={side}
                  className="rounded-md border border-[#2a303b] bg-[#161a21] p-2"
                >
                  <div className="text-xs uppercase text-[#99a2b3]">{side}</div>
                  <div className="text-lg font-semibold">
                    {formatAccuracy(acc)}
                  </div>
                  <div className="text-xs text-[#99a2b3]">
                    ACPL {acpl.toFixed(0)}
                  </div>
                </div>
              );
            })}
          </div>

          <div className="rounded-md border border-[#2a303b] bg-[#161a21] p-2">
            <div className="mb-1 text-xs uppercase text-[#99a2b3]">
              {review.opening ?? "Game"}
            </div>
            <div className="grid grid-cols-2 gap-x-3 gap-y-1 text-xs">
              {(Object.keys(review.counts) as (keyof typeof review.counts)[]).map(
                (k) => {
                  const c = review.counts[k];
                  if (c.w + c.b === 0) return null;
                  return (
                    <div key={k} className="contents">
                      <span className={classifyColor(k)}>
                        {classifyIcon(k)} {k}
                      </span>
                      <span className="font-mono text-[#99a2b3]">
                        {c.w}·{c.b}
                      </span>
                    </div>
                  );
                }
              )}
            </div>
          </div>

          <div className="max-h-72 overflow-auto rounded-md border border-[#2a303b] bg-[#161a21] p-1">
            <table className="w-full text-xs font-mono">
              <thead className="sticky top-0 bg-[#161a21] text-[#99a2b3]">
                <tr>
                  <th className="p-1 text-left">#</th>
                  <th className="p-1 text-left">Move</th>
                  <th className="p-1 text-left">Eval</th>
                  <th className="p-1 text-left">Class</th>
                </tr>
              </thead>
              <tbody>
                {review.moves.map((mv) => (
                  <tr key={mv.ply} className="border-t border-[#222933]">
                    <td className="p-1 text-[#99a2b3]">
                      {mv.moveNumber}
                      {mv.color === "w" ? "." : "…"}
                    </td>
                    <td className="p-1">{mv.san}</td>
                    <td className="p-1">
                      {(mv.evalAfterCp ?? 0) >= 0 ? "+" : ""}
                      {((mv.evalAfterCp ?? 0) / 100).toFixed(2)}
                    </td>
                    <td className={`p-1 ${classifyColor(mv.classification)}`}>
                      {classifyIcon(mv.classification)} {mv.classification}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
}
TSXEOF

cat > frontend/src/app/page.tsx << 'TSXEOF'
"use client";

import { useEffect, useState } from "react";
import Board from "@/components/Board";
import CoachPanel from "@/components/CoachPanel";
import EnginePanel from "@/components/EnginePanel";
import EvalBar from "@/components/EvalBar";
import Header from "@/components/Header";
import MoveList from "@/components/MoveList";
import ReviewPanel from "@/components/ReviewPanel";
import BoardSettingsPanel from "@/components/BoardSettingsPanel";
import { useGame } from "@/hooks/useGame";
import { fetchHealth } from "@/lib/api";
import { useSettings } from "@/lib/store";
import type { HealthResponse } from "@/lib/types";

type Tab = "play" | "engine" | "board" | "coach" | "review";

const TABS: { id: Tab; label: string }[] = [
  { id: "play", label: "Play" },
  { id: "engine", label: "Engine" },
  { id: "board", label: "Board" },
  { id: "coach", label: "Coach" },
  { id: "review", label: "Review" },
];

function findKingSquare(fen: string, turn: "w" | "b"): string | null {
  const rows = fen.split(" ")[0].split("/");
  const target = turn === "w" ? "K" : "k";
  for (let r = 0; r < 8; r++) {
    const row = rows[r];
    let file = 0;
    for (const ch of row) {
      if (/\d/.test(ch)) {
        file += Number(ch);
        continue;
      }
      if (ch === target) {
        const fileChar = "abcdefgh"[file];
        const rank = 8 - r;
        return `${fileChar}${rank}`;
      }
      file += 1;
    }
  }
  return null;
}

export default function HomePage() {
  const game = useGame();
  const { settings } = useSettings();
  const [tab, setTab] = useState<Tab>("play");
  const [health, setHealth] = useState<HealthResponse | null>(null);

  useEffect(() => {
    fetchHealth()
      .then(setHealth)
      .catch(() => setHealth(null));
  }, []);

  const orientation: "white" | "black" =
    game.playerColor === "w" ? "white" : "black";
  const pgn = game.getPgn();
  const checkSquare =
    game.status === "check" ? findKingSquare(game.fen, game.turn) : null;

  return (
    <main className="flex min-h-screen flex-col">
      <Header
        health={health}
        status={game.status}
        onNewGame={game.newGame}
        onUndo={game.undo}
        onResign={game.resign}
      />
      <div className="mx-auto grid w-full max-w-7xl flex-1 gap-3 px-3 py-3 md:grid-cols-[minmax(0,1fr)_minmax(320px,420px)]">
        <div className="flex min-w-0 gap-2">
          {settings.board.showEvalBar && (
            <div className="hidden w-7 shrink-0 sm:block">
              <EvalBar analysis={game.analysis} />
            </div>
          )}
          <div className="min-w-0 flex-1">
            <Board
              fen={game.fen}
              orientation={orientation}
              isPlayerTurn={game.isPlayerTurn}
              lastMove={game.lastMove}
              checkSquare={checkSquare}
              onMove={game.tryPlayerMove}
              legalMovesFor={game.legalMovesFor}
              analysis={game.analysis}
              pendingPromotion={game.pendingPromotion}
              onPromote={game.completePromotion}
              onCancelPromotion={game.cancelPromotion}
            />
            {game.isBotThinking && (
              <div className="mt-2 flex items-center gap-2 text-xs text-[#99a2b3]">
                <span className="dot-pulse">●</span> Engine is thinking…
              </div>
            )}
            {game.error && (
              <div className="mt-2 rounded-md border border-red-500/30 bg-red-500/5 p-2 text-xs text-red-300">
                {game.error}
              </div>
            )}
            <MoveList history={game.history} />
          </div>
        </div>

        <aside className="flex min-h-0 flex-col rounded-lg border border-[#2a303b] bg-[#0f1115]">
          <div className="flex overflow-x-auto border-b border-[#2a303b]">
            {TABS.map((t) => (
              <button
                key={t.id}
                onClick={() => setTab(t.id)}
                className={`whitespace-nowrap px-3 py-2 text-xs font-medium ${
                  tab === t.id
                    ? "border-b-2 border-[#6ea8fe] text-white"
                    : "text-[#99a2b3] hover:text-white"
                }`}
              >
                {t.label}
              </button>
            ))}
          </div>
          <div className="min-h-0 flex-1 overflow-auto">
            {tab === "play" && (
              <div className="space-y-3 p-3 text-sm">
                <div className="rounded-md border border-[#2a303b] bg-[#161a21] p-3">
                  <div className="mb-1 text-xs uppercase tracking-wide text-[#99a2b3]">
                    Play as
                  </div>
                  <div className="flex gap-2">
                    <button
                      onClick={() => game.newGame("w")}
                      className={`flex-1 rounded-md border px-2 py-1.5 ${
                        game.playerColor === "w"
                          ? "border-[#6ea8fe] bg-[#4d6bfe]/10"
                          : "border-[#2a303b]"
                      }`}
                    >
                      White
                    </button>
                    <button
                      onClick={() => game.newGame("b")}
                      className={`flex-1 rounded-md border px-2 py-1.5 ${
                        game.playerColor === "b"
                          ? "border-[#6ea8fe] bg-[#4d6bfe]/10"
                          : "border-[#2a303b]"
                      }`}
                    >
                      Black
                    </button>
                  </div>
                </div>
                <div className="rounded-md border border-[#2a303b] bg-[#161a21] p-3 text-xs">
                  <div className="flex justify-between">
                    <span className="text-[#99a2b3]">Bot</span>
                    <span className="font-mono">{settings.engine.kind}</span>
                  </div>
                  {settings.engine.kind === "stockfish" && (
                    <>
                      <div className="mt-1 flex justify-between">
                        <span className="text-[#99a2b3]">Strength</span>
                        <span className="font-mono">
                          {settings.engine.limitStrength
                            ? `${settings.engine.elo} Elo`
                            : `skill ${settings.engine.skillLevel}`}
                        </span>
                      </div>
                      <div className="mt-1 flex justify-between">
                        <span className="text-[#99a2b3]">Depth</span>
                        <span className="font-mono">{settings.engine.depth}</span>
                      </div>
                      <div className="mt-1 flex justify-between">
                        <span className="text-[#99a2b3]">Threads / Hash</span>
                        <span className="font-mono">
                          {settings.engine.threads} / {settings.engine.hashMb}MB
                        </span>
                      </div>
                    </>
                  )}
                  {settings.engine.kind === "maia" && (
                    <div className="mt-1 flex justify-between">
                      <span className="text-[#99a2b3]">Model</span>
                      <span className="font-mono">
                        {settings.engine.maiaModel}
                      </span>
                    </div>
                  )}
                </div>
                {game.analysis?.lines?.[0] && (
                  <div className="rounded-md border border-[#2a303b] bg-[#161a21] p-3 text-xs">
                    <div className="mb-1 text-[#99a2b3]">Engine best</div>
                    <div className="font-mono">
                      {game.analysis.lines[0].pvSan.slice(0, 6).join(" ")}
                    </div>
                  </div>
                )}
              </div>
            )}
            {tab === "engine" && <EnginePanel health={health} />}
            {tab === "board" && <BoardSettingsPanel />}
            {tab === "coach" && (
              <CoachPanel
                fen={game.fen}
                history={game.history}
                analysis={game.analysis}
                playerColor={game.playerColor}
                getPgn={game.getPgn}
              />
            )}
            {tab === "review" && <ReviewPanel pgn={pgn} />}
          </div>
        </aside>
      </div>
    </main>
  );
}
TSXEOF

echo ""
echo "✓ bootstrap-10 done. Files:"
find frontend/src/components frontend/src/app -type f | sort
echo ""
echo "Line counts:"
wc -l frontend/src/components/ReviewPanel.tsx frontend/src/app/page.tsx
echo ""
echo "=== FRONTEND COMPLETE ==="
echo ""
echo "Final steps:"
echo "  1. cd ~/chess-coach/frontend"
echo "  2. npx tsc --noEmit   (should be clean)"
echo "  3. npm run dev"
echo "  4. Open http://127.0.0.1:3000"
