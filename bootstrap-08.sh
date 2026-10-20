#!/usr/bin/env bash
# bootstrap-08.sh — components part 1: Board, EvalBar, Header, MoveList.
# Run from the repo root: bash bootstrap-08.sh
set -euo pipefail

[ -f frontend/src/hooks/useGame.ts ] || { echo "ERROR: run bootstrap-07 first"; exit 1; }
mkdir -p frontend/src/components

echo "→ bootstrap-08: components part 1"

cat > frontend/src/components/Board.tsx << 'TSXEOF'
"use client";

import { useState } from "react";
import { Chessboard } from "react-chessboard";
import { useSettings } from "@/lib/store";
import type { AnalysisResult, PendingPromotion } from "@/lib/types";

interface BoardProps {
  fen: string;
  orientation: "white" | "black";
  isPlayerTurn: boolean;
  lastMove: { from: string; to: string } | null;
  checkSquare: string | null;
  onMove: (from: string, to: string) => boolean;
  legalMovesFor: (square: string) => string[];
  analysis: AnalysisResult | null;
  pendingPromotion: PendingPromotion | null;
  onPromote: (piece: "q" | "r" | "b" | "n") => void;
  onCancelPromotion: () => void;
}

export default function Board({
  fen,
  orientation,
  isPlayerTurn,
  lastMove,
  checkSquare,
  onMove,
  legalMovesFor,
  analysis,
  pendingPromotion,
  onPromote,
  onCancelPromotion,
}: BoardProps) {
  const { settings } = useSettings();
  const [selected, setSelected] = useState<string | null>(null);
  const [legalTargets, setLegalTargets] = useState<Set<string>>(new Set());

  const clearSelection = () => {
    setSelected(null);
    setLegalTargets(new Set());
  };

  const squareStyles: Record<string, React.CSSProperties> = {};

  if (lastMove) {
    squareStyles[lastMove.from] = {
      backgroundColor: settings.board.lastMoveHighlight,
    };
    squareStyles[lastMove.to] = {
      backgroundColor: settings.board.lastMoveHighlight,
    };
  }

  if (selected) {
    squareStyles[selected] = { backgroundColor: settings.board.highlight };
  }

  if (settings.board.showLegalMoves) {
    legalTargets.forEach((sq) => {
      squareStyles[sq] = {
        ...(squareStyles[sq] || {}),
        backgroundImage:
          "radial-gradient(circle, rgba(0,0,0,0.28) 22%, transparent 24%)",
      };
    });
  }

  if (checkSquare) {
    squareStyles[checkSquare] = {
      backgroundColor: settings.board.checkHighlight,
    };
  }

  const arrows: unknown[] = [];
  if (settings.board.showArrows && analysis?.bestMoveUci) {
    const uci = analysis.bestMoveUci;
    arrows.push([uci.slice(0, 2), uci.slice(2, 4), "#4d6bfe"]);
  }

  const onSquareClick = (square: string) => {
    if (!isPlayerTurn) return;
    if (selected && legalTargets.has(square)) {
      onMove(selected, square);
      clearSelection();
      return;
    }
    if (selected === square) {
      clearSelection();
      return;
    }
    const targets = legalMovesFor(square);
    if (targets.length > 0) {
      setSelected(square);
      setLegalTargets(new Set(targets));
    } else {
      clearSelection();
    }
  };

  return (
    <div className="relative w-full">
      <Chessboard
        position={fen}
        boardOrientation={orientation}
        onPieceDrop={(from, to) => {
          const ok = onMove(from, to);
          clearSelection();
          return ok;
        }}
        onSquareClick={onSquareClick}
        customBoardStyle={{
          borderRadius: 12,
          boxShadow: "0 20px 60px rgba(0,0,0,0.45)",
        }}
        customLightSquareStyle={{ backgroundColor: settings.board.lightSquare }}
        customDarkSquareStyle={{ backgroundColor: settings.board.darkSquare }}
        customSquareStyles={squareStyles}
        customArrows={arrows as never}
        animationDuration={settings.board.animationMs}
        arePiecesDraggable={isPlayerTurn}
        showBoardNotation={settings.board.showCoordinates}
      />
      {pendingPromotion && (
        <div className="absolute inset-0 z-20 flex items-center justify-center rounded-xl bg-black/60">
          <div className="rounded-xl border border-[#2a303b] bg-[#161a21] p-4 shadow-2xl">
            <div className="mb-3 text-sm text-[#99a2b3]">
              Promote pawn to:
            </div>
            <div className="flex gap-2">
              {(["q", "r", "b", "n"] as const).map((p) => (
                <button
                  key={p}
                  onClick={() => onPromote(p)}
                  className="h-12 w-12 rounded-md border border-[#2a303b] bg-[#1d222b] text-xl font-semibold hover:border-[#6ea8fe]"
                >
                  {p.toUpperCase()}
                </button>
              ))}
            </div>
            <button
              onClick={onCancelPromotion}
              className="mt-3 w-full rounded-md border border-[#2a303b] py-1 text-xs text-[#99a2b3] hover:text-white"
            >
              Cancel
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
TSXEOF

cat > frontend/src/components/EvalBar.tsx << 'TSXEOF'
"use client";

import { evalToPercent, formatEval } from "@/lib/format";
import type { AnalysisResult } from "@/lib/types";

export default function EvalBar({
  analysis,
}: {
  analysis: AnalysisResult | null;
}) {
  const line = analysis?.lines[0] ?? null;
  const whitePct = evalToPercent(line);
  const label = formatEval(line);

  return (
    <div className="relative flex h-full w-7 flex-col overflow-hidden rounded-md border border-[#2a303b] bg-[#161a21]">
      <div
        className="bg-[#e8ebf1] transition-[height] duration-300"
        style={{ height: `${whitePct}%` }}
      />
      <div className="flex-1 bg-[#1d222b]" />
      <div className="absolute inset-x-0 top-1 text-center text-[10px] font-semibold text-black/70">
        {whitePct > 8 ? label : ""}
      </div>
    </div>
  );
}
TSXEOF

cat > frontend/src/components/Header.tsx << 'TSXEOF'
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
TSXEOF

cat > frontend/src/components/MoveList.tsx << 'TSXEOF'
"use client";

import type { Move } from "chess.js";

export default function MoveList({ history }: { history: Move[] }) {
  const rows: { n: number; w?: Move; b?: Move }[] = [];
  for (let i = 0; i < history.length; i += 2) {
    rows.push({ n: i / 2 + 1, w: history[i], b: history[i + 1] });
  }
  if (rows.length === 0) {
    return (
      <div className="mt-3 rounded-md border border-[#2a303b] bg-[#161a21] p-3 text-xs text-[#99a2b3]">
        No moves yet.
      </div>
    );
  }
  return (
    <div className="mt-3 max-h-48 overflow-auto rounded-md border border-[#2a303b] bg-[#161a21] p-2 text-sm">
      <div className="grid grid-cols-[auto_1fr_1fr] gap-x-3 gap-y-1 font-mono">
        {rows.map((r) => (
          <div key={r.n} className="contents">
            <span className="text-[#99a2b3]">{r.n}.</span>
            <span>{r.w?.san ?? ""}</span>
            <span>{r.b?.san ?? ""}</span>
          </div>
        ))}
      </div>
    </div>
  );
}
TSXEOF

echo ""
echo "✓ bootstrap-08 done. Files:"
find frontend/src/components -type f | sort
echo ""
echo "Line counts:"
wc -l frontend/src/components/*.tsx
echo ""
echo "Next: bootstrap-09 (EnginePanel, BoardSettingsPanel, CoachPanel)"
