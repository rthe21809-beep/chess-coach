"use client";

import type { GameStatus, HealthResponse } from "@/lib/types";

interface HeaderProps {
  health: HealthResponse | null;
  status: GameStatus;
  onNewGame: (color: "w" | "b") => void;
  onUndo: () => void;
  onResign: () => void;
}

export default function Header({
  health,
  status,
  onNewGame,
  onUndo,
  onResign,
}: HeaderProps) {
  const sf = health?.engines?.stockfish;
  const groq = health?.groqConfigured;

  return (
    <header className="sticky top-0 z-10 border-b border-[#2a303b] bg-[#0f1115]/85 backdrop-blur">
      <div className="mx-auto flex w-full max-w-7xl items-center gap-3 px-3 py-2">
        <div className="flex items-center gap-2">
          <span className="text-lg font-semibold tracking-tight">
            Chess Coach
          </span>
          <span className="hidden text-xs text-[#99a2b3] sm:inline">
            {status === "playing" && "playing"}
            {status === "check" && "check"}
            {status === "checkmate" && "checkmate"}
            {status === "draw" && "draw"}
            {status === "stalemate" && "stalemate"}
            {status === "resigned" && "resigned"}
          </span>
        </div>
        <div className="ml-auto flex items-center gap-2 text-xs">
          <span
            className={`rounded px-2 py-0.5 ${
              sf?.available
                ? "bg-emerald-500/10 text-emerald-300"
                : "bg-red-500/10 text-red-300"
            }`}
          >
            {sf?.available ? "stockfish ready" : "no stockfish"}
          </span>
          <span
            className={`rounded px-2 py-0.5 ${
              groq
                ? "bg-emerald-500/10 text-emerald-300"
                : "bg-amber-500/10 text-amber-300"
            }`}
          >
            {groq ? "coach online" : "offline coach"}
          </span>
        </div>
      </div>
      <div className="mx-auto flex w-full max-w-7xl flex-wrap gap-2 px-3 pb-2 text-xs">
        <button
          className="rounded-md border border-[#2a303b] px-2 py-1 hover:border-[#6ea8fe]"
          onClick={() => onNewGame("w")}
        >
          New as White
        </button>
        <button
          className="rounded-md border border-[#2a303b] px-2 py-1 hover:border-[#6ea8fe]"
          onClick={() => onNewGame("b")}
        >
          New as Black
        </button>
        <button
          className="rounded-md border border-[#2a303b] px-2 py-1 hover:border-[#6ea8fe]"
          onClick={onUndo}
        >
          Undo
        </button>
        <button
          className="rounded-md border border-[#2a303b] px-2 py-1 hover:border-red-400 hover:text-red-300"
          onClick={onResign}
        >
          Resign
        </button>
      </div>
    </header>
  );
}
