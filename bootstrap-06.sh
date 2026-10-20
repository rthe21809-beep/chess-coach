#!/usr/bin/env bash
# bootstrap-06.sh — lib layer: types, format, sounds, store.
# Run from the repo root: bash bootstrap-06.sh
set -euo pipefail

[ -f frontend/package.json ] || { echo "ERROR: run bootstrap-05 first"; exit 1; }
mkdir -p frontend/src/lib

echo "→ bootstrap-06: lib/types, format, sounds, store"

cat > frontend/src/lib/types.ts << 'TSEOF'
// Shared TypeScript types for the entire frontend.
// Shapes mirror backend/app/models.py (camelCase over the wire).

export type EngineKind = "stockfish" | "maia";

export interface EngineSettings {
  kind: EngineKind;
  limitStrength: boolean;
  elo: number;
  skillLevel: number;
  depth: number;
  moveTimeMs: number;
  threads: number;
  hashMb: number;
  multiPv: number;
  maiaModel: string;
}

export interface BoardSettings {
  lightSquare: string;
  darkSquare: string;
  highlight: string;
  lastMoveHighlight: string;
  checkHighlight: string;
  animationMs: number;
  showCoordinates: boolean;
  showLegalMoves: boolean;
  showArrows: boolean;
  showEvalBar: boolean;
  soundEnabled: boolean;
  volume: number;
  autoFlip: boolean;
}

export interface CoachSettings {
  model: string;
  temperature: number;
  stream: boolean;
  playerRating: number;
  language: string;
}

export interface Settings {
  engine: EngineSettings;
  board: BoardSettings;
  coach: CoachSettings;
}

export interface AnalysisLine {
  multipv: number;
  scoreCp: number | null;
  mate: number | null;
  pvSan: string[];
  pvUci: string[];
  depth: number;
}

export type AnalysisSource = "local" | "lichess" | "chess-api" | "none";

export interface AnalysisResult {
  fen: string;
  depth: number;
  nodes: number;
  timeMs: number;
  source: AnalysisSource;
  bestMoveUci: string | null;
  bestMoveSan: string | null;
  lines: AnalysisLine[];
  error?: string | null;
}

export interface BotMoveResponse {
  uci: string | null;
  san: string | null;
  promotion: string | null;
  analysis: AnalysisResult | null;
}

export type MoveClass =
  | "brilliant"
  | "great"
  | "best"
  | "excellent"
  | "good"
  | "book"
  | "inaccuracy"
  | "mistake"
  | "blunder"
  | "miss";

export interface ReviewedMove {
  ply: number;
  moveNumber: number;
  color: "w" | "b";
  san: string;
  uci: string;
  fenBefore: string;
  fenAfter: string;
  evalBeforeCp: number | null;
  evalAfterCp: number | null;
  mateBefore: number | null;
  mateAfter: number | null;
  cpLoss: number;
  classification: MoveClass;
  bestMoveSan: string | null;
  bestMoveUci: string | null;
}

export interface GameReview {
  whiteAccuracy: number;
  blackAccuracy: number;
  whiteAcpl: number;
  blackAcpl: number;
  counts: Record<MoveClass, { w: number; b: number }>;
  moves: ReviewedMove[];
  opening: string | null;
  source: string;
}

export interface ReviewProgress {
  done: number;
  total: number;
}

export interface CoachMessage {
  role: "system" | "user" | "assistant";
  content: string;
}

export interface CoachContext {
  fen: string;
  pgn: string | null;
  lastMoves: string[];
  playerColor: "w" | "b";
  playerRating: number;
  language: string;
  fenBefore: string | null;
  lastMoveSan: string | null;
  analysis: AnalysisResult | null;
  extraContext: string | null;
}

export interface ChatUiMessage {
  id: string;
  role: "user" | "assistant";
  content: string;
  streaming?: boolean;
  error?: boolean;
  createdAt: number;
}

export interface EngineOptionRange {
  min: number | null;
  max: number | null;
}

export interface EngineStatus {
  available: boolean;
  path: string;
  error: string | null;
  options: Record<string, EngineOptionRange>;
}

export interface HealthResponse {
  ok: boolean;
  version: string;
  groqConfigured: boolean;
  cloudFallback: boolean;
  engines: Record<EngineKind, EngineStatus>;
  suggestedModels: string[];
  defaultModel: string;
}

export type GameStatus =
  | "playing"
  | "check"
  | "checkmate"
  | "stalemate"
  | "draw"
  | "resigned";

export interface PendingPromotion {
  from: string;
  to: string;
  color: "w" | "b";
}
TSEOF

cat > frontend/src/lib/format.ts << 'TSEOF'
// Formatting helpers for evals, classifications, and numbers.

export function formatEval(
  line?: { scoreCp: number | null; mate: number | null } | null,
  perspective: "white" | "black" = "white"
): string {
  if (!line) return "—";
  if (line.mate !== null && line.mate !== undefined) {
    const v = perspective === "white" ? line.mate : -line.mate;
    return `${v > 0 ? "+" : "-"}M${Math.abs(line.mate)}`;
  }
  if (line.scoreCp === null || line.scoreCp === undefined) return "—";
  const cp = perspective === "white" ? line.scoreCp : -line.scoreCp;
  return `${cp >= 0 ? "+" : ""}${(cp / 100).toFixed(2)}`;
}

export function evalToPercent(
  line?: { scoreCp: number | null; mate: number | null } | null
): number {
  if (!line) return 50;
  if (line.mate !== null && line.mate !== undefined) return line.mate > 0 ? 100 : 0;
  const cp = Math.max(-1200, Math.min(1200, line.scoreCp ?? 0));
  return 50 + 50 * (2 / (1 + Math.exp(-0.00368208 * cp)) - 1);
}

export function classifyColor(cls: string): string {
  switch (cls) {
    case "brilliant": return "text-cyan-300";
    case "great": return "text-blue-300";
    case "best": return "text-emerald-300";
    case "excellent": return "text-green-300";
    case "good": return "text-slate-300";
    case "book": return "text-amber-300";
    case "inaccuracy": return "text-yellow-300";
    case "mistake": return "text-orange-300";
    case "blunder": return "text-red-400";
    case "miss": return "text-pink-400";
    default: return "text-slate-300";
  }
}

export function classifyIcon(cls: string): string {
  switch (cls) {
    case "brilliant": return "!!";
    case "great": return "!";
    case "best": return "★";
    case "excellent": return "✓";
    case "good": return "·";
    case "book": return "📖";
    case "inaccuracy": return "?!";
    case "mistake": return "?";
    case "blunder": return "??";
    case "miss": return "✗";
    default: return "";
  }
}

export function formatNodes(n: number): string {
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
  if (n >= 1_000) return `${(n / 1_000).toFixed(0)}k`;
  return String(n);
}

export function formatAccuracy(a: number): string {
  return `${a.toFixed(1)}%`;
}
TSEOF

cat > frontend/src/lib/sounds.ts << 'TSEOF'
// Minimal Web Audio SFX for moves, captures, check, castles, game end.
// Lazily creates one AudioContext (browsers require a user gesture first).

let ctx: AudioContext | null = null;

function audio(): AudioContext | null {
  if (typeof window === "undefined") return null;
  if (!ctx) {
    const AC =
      window.AudioContext ||
      (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
    if (!AC) return null;
    ctx = new AC();
  }
  if (ctx.state === "suspended") void ctx.resume();
  return ctx;
}

function tone(
  freq: number,
  durMs: number,
  volume: number,
  type: OscillatorType = "triangle"
) {
  const c = audio();
  if (!c) return;
  const osc = c.createOscillator();
  const gain = c.createGain();
  osc.type = type;
  osc.frequency.value = freq;
  gain.gain.setValueAtTime(volume, c.currentTime);
  gain.gain.exponentialRampToValueAtTime(0.0001, c.currentTime + durMs / 1000);
  osc.connect(gain);
  gain.connect(c.destination);
  osc.start();
  osc.stop(c.currentTime + durMs / 1000 + 0.02);
}

export function playMove(volume = 0.35) {
  tone(320, 70, volume);
}
export function playCapture(volume = 0.35) {
  tone(220, 90, volume, "square");
}
export function playCheck(volume = 0.35) {
  tone(660, 90, volume);
  setTimeout(() => tone(880, 100, volume), 60);
}
export function playCastle(volume = 0.35) {
  tone(440, 60, volume);
  setTimeout(() => tone(520, 60, volume), 60);
}
export function playGameEnd(volume = 0.35) {
  tone(440, 200, volume);
  setTimeout(() => tone(330, 250, volume), 200);
}
export function playPromote(volume = 0.35) {
  tone(660, 120, volume);
  setTimeout(() => tone(880, 140, volume), 100);
}

export function playForMove(
  opts: {
    capture?: boolean;
    check?: boolean;
    castle?: boolean;
    promote?: boolean;
    end?: boolean;
  },
  volume: number
) {
  if (opts.end) return playGameEnd(volume);
  if (opts.promote) return playPromote(volume);
  if (opts.castle) return playCastle(volume);
  if (opts.check) return playCheck(volume);
  if (opts.capture) return playCapture(volume);
  playMove(volume);
}
TSEOF

cat > frontend/src/lib/store.ts << 'TSEOF'
// Persisted user settings via zustand. Stored in localStorage under "chess-coach-settings".

import { create } from "zustand";
import { persist } from "zustand/middleware";
import type {
  BoardSettings,
  CoachSettings,
  EngineSettings,
  Settings,
} from "./types";

export const DEFAULT_ENGINE: EngineSettings = {
  kind: "stockfish",
  limitStrength: true,
  elo: 1600,
  skillLevel: 20,
  depth: 14,
  moveTimeMs: 800,
  threads: 1,
  hashMb: 64,
  multiPv: 1,
  maiaModel: "maia-1500",
};

export const DEFAULT_BOARD: BoardSettings = {
  lightSquare: "#ecd9b0",
  darkSquare: "#779556",
  highlight: "rgba(255,255,0,0.35)",
  lastMoveHighlight: "rgba(255,255,0,0.22)",
  checkHighlight: "rgba(255,0,0,0.55)",
  animationMs: 200,
  showCoordinates: true,
  showLegalMoves: true,
  showArrows: true,
  showEvalBar: true,
  soundEnabled: true,
  volume: 0.35,
  autoFlip: false,
};

export const DEFAULT_COACH: CoachSettings = {
  model: "openai/gpt-oss-120b",
  temperature: 0.4,
  stream: true,
  playerRating: 1200,
  language: "English",
};

export const DEFAULT_SETTINGS: Settings = {
  engine: DEFAULT_ENGINE,
  board: DEFAULT_BOARD,
  coach: DEFAULT_COACH,
};

interface Store {
  settings: Settings;
  setEngine: (patch: Partial<EngineSettings>) => void;
  setBoard: (patch: Partial<BoardSettings>) => void;
  setCoach: (patch: Partial<CoachSettings>) => void;
  reset: () => void;
}

export const useSettings = create<Store>()(
  persist(
    (set) => ({
      settings: DEFAULT_SETTINGS,
      setEngine: (p) =>
        set((s) => ({
          settings: { ...s.settings, engine: { ...s.settings.engine, ...p } },
        })),
      setBoard: (p) =>
        set((s) => ({
          settings: { ...s.settings, board: { ...s.settings.board, ...p } },
        })),
      setCoach: (p) =>
        set((s) => ({
          settings: { ...s.settings, coach: { ...s.settings.coach, ...p } },
        })),
      reset: () => set({ settings: DEFAULT_SETTINGS }),
    }),
    { name: "chess-coach-settings" }
  )
);
TSEOF

echo ""
echo "✓ bootstrap-06 done. Files:"
find frontend/src/lib -type f | sort
echo ""
echo "Next: bootstrap-07 (lib/api.ts + hooks/useGame.ts)"
