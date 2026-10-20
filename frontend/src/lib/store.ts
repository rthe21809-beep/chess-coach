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
