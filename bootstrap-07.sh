#!/usr/bin/env bash
# bootstrap-07.sh — lib/api.ts + hooks/useGame.ts
# Run from the repo root: bash bootstrap-07.sh
set -euo pipefail

[ -f frontend/src/lib/types.ts ] || { echo "ERROR: run bootstrap-06 first"; exit 1; }
mkdir -p frontend/src/hooks

echo "→ bootstrap-07: api.ts + useGame.ts"

cat > frontend/src/lib/api.ts << 'TSEOF'
// HTTP + SSE client for the local FastAPI backend.

import type {
  AnalysisResult,
  BotMoveResponse,
  CoachContext,
  EngineSettings,
  GameReview,
  HealthResponse,
  ReviewProgress,
} from "./types";

export const API_BASE =
  process.env.NEXT_PUBLIC_API_BASE || "http://127.0.0.1:8000";

async function postJson<T>(path: string, body: unknown): Promise<T> {
  const res = await fetch(`${API_BASE}${path}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    const text = await res.text().catch(() => "");
    throw new Error(
      `${res.status} ${res.statusText}${text ? ": " + text.slice(0, 300) : ""}`
    );
  }
  return res.json() as Promise<T>;
}

async function getJson<T>(path: string): Promise<T> {
  const res = await fetch(`${API_BASE}${path}`);
  if (!res.ok) throw new Error(`${res.status} ${res.statusText}`);
  return res.json() as Promise<T>;
}

export const fetchHealth = () => getJson<HealthResponse>("/api/system/health");

export const analyzePosition = (
  fen: string,
  params: EngineSettings,
  opts?: { depth?: number; multipv?: number }
) => postJson<AnalysisResult>("/api/engine/analyze", { fen, params, ...opts });

export const requestBotMove = (fen: string, params: EngineSettings) =>
  postJson<BotMoveResponse>("/api/engine/move", { fen, params });

// ── SSE ─────────────────────────────────────────────────────────────────────

interface SseEvent {
  event?: string;
  data: unknown;
}

async function* sseStream(
  path: string,
  body: unknown
): AsyncGenerator<SseEvent> {
  const res = await fetch(`${API_BASE}${path}`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Accept: "text/event-stream" },
    body: JSON.stringify(body),
  });
  if (!res.ok || !res.body) {
    const text = await res.text().catch(() => "");
    throw new Error(
      `${res.status} ${res.statusText}${text ? ": " + text.slice(0, 300) : ""}`
    );
  }
  const reader = res.body.getReader();
  const decoder = new TextDecoder();
  let buffer = "";
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    buffer += decoder.decode(value, { stream: true });
    const blocks = buffer.split("\n\n");
    buffer = blocks.pop() ?? "";
    for (const block of blocks) {
      let event: string | undefined;
      const dataLines: string[] = [];
      for (const line of block.split("\n")) {
        if (line.startsWith("event:")) event = line.slice(6).trim();
        else if (line.startsWith("data:")) dataLines.push(line.slice(5).trimStart());
      }
      if (dataLines.length === 0) continue;
      const dataStr = dataLines.join("\n");
      try {
        yield { event, data: JSON.parse(dataStr) };
      } catch {
        // skip non-JSON block
      }
    }
  }
}

// ── coach chat stream ───────────────────────────────────────────────────────

export interface CoachChatPayload {
  messages: { role: "user" | "assistant"; content: string }[];
  context: CoachContext;
  params: EngineSettings;
  model: string;
  temperature: number;
  stream: boolean;
}

export async function* streamCoachChat(
  payload: CoachChatPayload
): AsyncGenerator<{
  delta?: string;
  done?: boolean;
  error?: string;
  offline?: boolean;
}> {
  for await (const ev of sseStream("/api/coach/chat", payload)) {
    if (ev.event === "error") {
      const d = ev.data as { detail?: string } | null;
      yield { error: d?.detail ?? "Coach error" };
      return;
    }
    const d = ev.data as
      | { delta?: string; done?: boolean; offline?: boolean; detail?: string }
      | null;
    if (d?.delta !== undefined) yield { delta: d.delta };
    if (d?.done) {
      yield { done: true, offline: d.offline };
      return;
    }
    if (d?.detail) {
      yield { error: d.detail };
      return;
    }
  }
}

// ── game review stream ──────────────────────────────────────────────────────

export async function* streamReview(
  pgn: string,
  params: EngineSettings,
  depth: number
): AsyncGenerator<
  | { kind: "progress"; data: ReviewProgress }
  | { kind: "result"; data: GameReview }
  | { kind: "error"; message: string }
> {
  for await (const ev of sseStream("/api/review", { pgn, params, depth })) {
    if (ev.event === "progress") {
      yield { kind: "progress", data: ev.data as ReviewProgress };
    } else if (ev.event === "result") {
      yield { kind: "result", data: ev.data as GameReview };
    } else if (ev.event === "error") {
      const d = ev.data as { detail?: string } | null;
      yield { kind: "error", message: d?.detail ?? "Review failed" };
      return;
    }
  }
}
TSEOF

cat > frontend/src/hooks/useGame.ts << 'TSEOF'
"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { Chess, type Move, type Square } from "chess.js";
import { requestBotMove } from "@/lib/api";
import { playForMove } from "@/lib/sounds";
import { useSettings } from "@/lib/store";
import type { AnalysisResult, GameStatus, PendingPromotion } from "@/lib/types";

export function useGame() {
  const { settings } = useSettings();
  const gameRef = useRef(new Chess());
  const [fen, setFen] = useState(gameRef.current.fen());
  const [history, setHistory] = useState<Move[]>([]);
  const [playerColor, setPlayerColor] = useState<"w" | "b">("w");
  const [isBotThinking, setIsBotThinking] = useState(false);
  const [analysis, setAnalysis] = useState<AnalysisResult | null>(null);
  const [pendingPromotion, setPendingPromotion] =
    useState<PendingPromotion | null>(null);
  const [status, setStatus] = useState<GameStatus>("playing");
  const [error, setError] = useState<string | null>(null);
  const botLoopRef = useRef(false);

  const refresh = useCallback(() => {
    const g = gameRef.current;
    setFen(g.fen());
    setHistory(g.history({ verbose: true }) as Move[]);
    if (g.isCheckmate()) setStatus("checkmate");
    else if (
      g.isStalemate() ||
      g.isDraw() ||
      g.isThreefoldRepetition() ||
      g.isInsufficientMaterial()
    )
      setStatus("draw");
    else if (g.inCheck()) setStatus("check");
    else setStatus("playing");
  }, []);

  const makeMove = useCallback(
    (from: string, to: string, promotion?: string): boolean => {
      const g = gameRef.current;
      try {
        const mv = g.move({
          from,
          to,
          promotion: promotion as "q" | "r" | "b" | "n" | undefined,
        });
        if (!mv) return false;
        playForMove(
          {
            capture: !!mv.captured,
            castle: mv.san === "O-O" || mv.san === "O-O-O",
            check: g.inCheck(),
            promote: !!mv.promotion,
            end: g.isGameOver(),
          },
          settings.board.volume
        );
        refresh();
        return true;
      } catch {
        return false;
      }
    },
    [refresh, settings.board.volume]
  );

  const legalMovesFor = useCallback(
    (square: string): string[] => {
      const g = gameRef.current;
      if (g.turn() !== playerColor) return [];
      const moves = g.moves({ square: square as Square, verbose: true }) as Move[];
      return moves.map((m) => m.to);
    },
    [playerColor]
  );

  const tryPlayerMove = useCallback(
    (from: string, to: string): boolean => {
      const g = gameRef.current;
      if (g.turn() !== playerColor) return false;
      const legal = g.moves({ square: from as Square, verbose: true }) as Move[];
      const needsPromotion = legal.some(
        (m) => m.from === from && m.to === to && m.promotion
      );
      if (needsPromotion) {
        setPendingPromotion({ from, to, color: playerColor });
        return false;
      }
      return makeMove(from, to);
    },
    [makeMove, playerColor]
  );

  const completePromotion = useCallback(
    (piece: "q" | "r" | "b" | "n") => {
      if (!pendingPromotion) return;
      makeMove(pendingPromotion.from, pendingPromotion.to, piece);
      setPendingPromotion(null);
    },
    [makeMove, pendingPromotion]
  );

  const cancelPromotion = useCallback(() => setPendingPromotion(null), []);

  const requestBotReply = useCallback(async () => {
    if (botLoopRef.current) return;
    botLoopRef.current = true;
    setIsBotThinking(true);
    setError(null);
    try {
      const reply = await requestBotMove(gameRef.current.fen(), settings.engine);
      if (reply.analysis) setAnalysis(reply.analysis);
      if (reply.uci) {
        const from = reply.uci.slice(0, 2);
        const to = reply.uci.slice(2, 4);
        const promo = reply.uci.length > 4 ? reply.uci[4] : undefined;
        makeMove(from, to, promo);
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setIsBotThinking(false);
      botLoopRef.current = false;
    }
  }, [makeMove, settings.engine]);

  // Stable ref so the effect below does not re-run when requestBotReply's identity changes.
  const requestBotReplyRef = useRef(requestBotReply);
  useEffect(() => {
    requestBotReplyRef.current = requestBotReply;
  }, [requestBotReply]);

  useEffect(() => {
    const g = gameRef.current;
    if (g.isGameOver()) return;
    if (g.turn() === playerColor) return;
    if (isBotThinking || botLoopRef.current) return;
    void requestBotReplyRef.current();
  }, [fen, isBotThinking, playerColor]);

  const newGame = useCallback(
    (asColor: "w" | "b" = "w") => {
      gameRef.current = new Chess();
      setPlayerColor(asColor);
      setAnalysis(null);
      setError(null);
      setPendingPromotion(null);
      setStatus("playing");
      refresh();
    },
    [refresh]
  );

  const undo = useCallback(() => {
    const g = gameRef.current;
    g.undo();
    if (g.turn() !== playerColor) g.undo();
    refresh();
  }, [playerColor, refresh]);

  const resign = useCallback(() => setStatus("resigned"), []);

  const getPgn = useCallback(() => gameRef.current.pgn(), []);

  const state = useMemo(() => {
    const g = gameRef.current;
    const last = history[history.length - 1];
    return {
      fen,
      history,
      turn: g.turn(),
      status,
      isPlayerTurn: g.turn() === playerColor && !g.isGameOver(),
      isBotThinking,
      playerColor,
      lastMove: last ? { from: last.from, to: last.to } : null,
      analysis,
      pendingPromotion,
    };
  }, [
    analysis,
    fen,
    history,
    isBotThinking,
    pendingPromotion,
    playerColor,
    status,
  ]);

  return {
    ...state,
    error,
    makeMove,
    tryPlayerMove,
    completePromotion,
    cancelPromotion,
    newGame,
    undo,
    resign,
    getPgn,
    setPlayerColor,
    setAnalysis,
    legalMovesFor,
    game: gameRef.current,
  };
}
TSEOF

echo ""
echo "✓ bootstrap-07 done. Files:"
ls -la frontend/src/lib/api.ts frontend/src/hooks/useGame.ts 2>&1
echo ""
echo "Line counts:"
wc -l frontend/src/lib/api.ts frontend/src/hooks/useGame.ts
echo ""
echo "Next: bootstrap-08 (components part 1: Board, EvalBar, Header, MoveList)"
