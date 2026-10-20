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
