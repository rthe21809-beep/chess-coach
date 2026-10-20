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
