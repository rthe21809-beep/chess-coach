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
