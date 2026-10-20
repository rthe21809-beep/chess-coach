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
