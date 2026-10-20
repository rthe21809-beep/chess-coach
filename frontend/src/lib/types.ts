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
