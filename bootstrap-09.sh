#!/usr/bin/env bash
# bootstrap-09.sh — components part 2: EnginePanel, BoardSettingsPanel, CoachPanel.
# Run from the repo root: bash bootstrap-09.sh
set -euo pipefail

[ -f frontend/src/components/Board.tsx ] || { echo "ERROR: run bootstrap-08 first"; exit 1; }

echo "→ bootstrap-09: components part 2"

cat > frontend/src/components/EnginePanel.tsx << 'TSXEOF'
"use client";

import { useSettings } from "@/lib/store";
import type { HealthResponse } from "@/lib/types";

export default function EnginePanel({
  health,
}: {
  health: HealthResponse | null;
}) {
  const { settings, setEngine } = useSettings();
  const e = settings.engine;
  const sf = health?.engines?.stockfish;
  const maia = health?.engines?.maia;
  const eloRange = sf?.options?.UCI_Elo;

  return (
    <div className="space-y-3 p-3 text-sm">
      <div className="rounded-md border border-[#2a303b] bg-[#161a21] p-3">
        <div className="mb-2 text-xs uppercase tracking-wide text-[#99a2b3]">
          Engine
        </div>
        <div className="flex gap-2">
          <button
            onClick={() => setEngine({ kind: "stockfish" })}
            className={`flex-1 rounded-md border px-2 py-1.5 ${
              e.kind === "stockfish"
                ? "border-[#6ea8fe] bg-[#4d6bfe]/10"
                : "border-[#2a303b]"
            }`}
          >
            Stockfish
          </button>
          <button
            onClick={() => setEngine({ kind: "maia" })}
            className={`flex-1 rounded-md border px-2 py-1.5 ${
              e.kind === "maia"
                ? "border-[#6ea8fe] bg-[#4d6bfe]/10"
                : "border-[#2a303b]"
            }`}
          >
            Maia
            {!maia?.available && (
              <span className="ml-1 text-[10px] text-[#99a2b3]">
                (unavailable)
              </span>
            )}
          </button>
        </div>
        {e.kind === "maia" && (
          <label className="mt-2 block">
            <span className="text-xs text-[#99a2b3]">Maia model</span>
            <select
              className="mt-1 w-full rounded-md border border-[#2a303b] bg-[#1d222b] px-2 py-1"
              value={e.maiaModel}
              onChange={(ev) => setEngine({ maiaModel: ev.target.value })}
            >
              {["maia-1100", "maia-1300", "maia-1500", "maia-1700", "maia-1900"].map(
                (m) => (
                  <option key={m} value={m}>
                    {m}
                  </option>
                )
              )}
            </select>
          </label>
        )}
      </div>

      {e.kind === "stockfish" && (
        <div className="space-y-3 rounded-md border border-[#2a303b] bg-[#161a21] p-3">
          <label className="flex items-center justify-between">
            <span>Limit strength</span>
            <input
              type="checkbox"
              checked={e.limitStrength}
              onChange={(ev) => setEngine({ limitStrength: ev.target.checked })}
            />
          </label>
          {e.limitStrength ? (
            <label className="block">
              <div className="flex justify-between text-xs text-[#99a2b3]">
                <span>Elo</span>
                <span className="font-mono">{e.elo}</span>
              </div>
              <input
                type="range"
                min={eloRange?.min ?? 1320}
                max={eloRange?.max ?? 3190}
                step={10}
                value={e.elo}
                onChange={(ev) => setEngine({ elo: Number(ev.target.value) })}
              />
            </label>
          ) : (
            <label className="block">
              <div className="flex justify-between text-xs text-[#99a2b3]">
                <span>Skill level</span>
                <span className="font-mono">{e.skillLevel}</span>
              </div>
              <input
                type="range"
                min={0}
                max={20}
                step={1}
                value={e.skillLevel}
                onChange={(ev) =>
                  setEngine({ skillLevel: Number(ev.target.value) })
                }
              />
            </label>
          )}
          <label className="block">
            <div className="flex justify-between text-xs text-[#99a2b3]">
              <span>Depth</span>
              <span className="font-mono">{e.depth}</span>
            </div>
            <input
              type="range"
              min={1}
              max={24}
              step={1}
              value={e.depth}
              onChange={(ev) => setEngine({ depth: Number(ev.target.value) })}
            />
          </label>
          <label className="block">
            <div className="flex justify-between text-xs text-[#99a2b3]">
              <span>Think time (ms)</span>
              <span className="font-mono">{e.moveTimeMs}</span>
            </div>
            <input
              type="range"
              min={100}
              max={4000}
              step={100}
              value={e.moveTimeMs}
              onChange={(ev) =>
                setEngine({ moveTimeMs: Number(ev.target.value) })
              }
            />
          </label>
          <label className="block">
            <div className="flex justify-between text-xs text-[#99a2b3]">
              <span>Threads</span>
              <span className="font-mono">{e.threads}</span>
            </div>
            <input
              type="range"
              min={1}
              max={8}
              step={1}
              value={e.threads}
              onChange={(ev) => setEngine({ threads: Number(ev.target.value) })}
            />
          </label>
          <label className="block">
            <div className="flex justify-between text-xs text-[#99a2b3]">
              <span>Hash (MB)</span>
              <span className="font-mono">{e.hashMb}</span>
            </div>
            <input
              type="range"
              min={16}
              max={512}
              step={16}
              value={e.hashMb}
              onChange={(ev) => setEngine({ hashMb: Number(ev.target.value) })}
            />
          </label>
          <label className="block">
            <div className="flex justify-between text-xs text-[#99a2b3]">
              <span>MultiPV</span>
              <span className="font-mono">{e.multiPv}</span>
            </div>
            <input
              type="range"
              min={1}
              max={5}
              step={1}
              value={e.multiPv}
              onChange={(ev) => setEngine({ multiPv: Number(ev.target.value) })}
            />
          </label>
        </div>
      )}

      {!sf?.available && (
        <div className="rounded-md border border-red-500/30 bg-red-500/5 p-3 text-xs text-red-300">
          {sf?.error ?? "Stockfish is not available."}
        </div>
      )}
    </div>
  );
}
TSXEOF

cat > frontend/src/components/BoardSettingsPanel.tsx << 'TSXEOF'
"use client";

import { useSettings } from "@/lib/store";
import type { BoardSettings } from "@/lib/types";

export default function BoardSettingsPanel() {
  const { settings, setBoard, reset } = useSettings();
  const b = settings.board;

  const update = <K extends keyof BoardSettings>(key: K, value: BoardSettings[K]) =>
    setBoard({ [key]: value } as Partial<BoardSettings>);

  return (
    <div className="space-y-3 p-3 text-sm">
      <div className="space-y-3 rounded-md border border-[#2a303b] bg-[#161a21] p-3">
        <div className="text-xs uppercase tracking-wide text-[#99a2b3]">
          Colors
        </div>
        <label className="flex items-center justify-between">
          <span>Light square</span>
          <input
            type="color"
            value={b.lightSquare}
            onChange={(e) => update("lightSquare", e.target.value)}
          />
        </label>
        <label className="flex items-center justify-between">
          <span>Dark square</span>
          <input
            type="color"
            value={b.darkSquare}
            onChange={(e) => update("darkSquare", e.target.value)}
          />
        </label>
        <label className="block">
          <div className="flex justify-between text-xs text-[#99a2b3]">
            <span>Animation (ms)</span>
            <span className="font-mono">{b.animationMs}</span>
          </div>
          <input
            type="range"
            min={0}
            max={600}
            step={20}
            value={b.animationMs}
            onChange={(e) => update("animationMs", Number(e.target.value))}
          />
        </label>
        <label className="block">
          <div className="flex justify-between text-xs text-[#99a2b3]">
            <span>Volume</span>
            <span className="font-mono">{Math.round(b.volume * 100)}%</span>
          </div>
          <input
            type="range"
            min={0}
            max={1}
            step={0.05}
            value={b.volume}
            onChange={(e) => update("volume", Number(e.target.value))}
          />
        </label>
      </div>

      <div className="space-y-2 rounded-md border border-[#2a303b] bg-[#161a21] p-3">
        <label className="flex items-center justify-between">
          <span>Show coordinates</span>
          <input
            type="checkbox"
            checked={b.showCoordinates}
            onChange={(e) => update("showCoordinates", e.target.checked)}
          />
        </label>
        <label className="flex items-center justify-between">
          <span>Legal-move dots</span>
          <input
            type="checkbox"
            checked={b.showLegalMoves}
            onChange={(e) => update("showLegalMoves", e.target.checked)}
          />
        </label>
        <label className="flex items-center justify-between">
          <span>Best-move arrow</span>
          <input
            type="checkbox"
            checked={b.showArrows}
            onChange={(e) => update("showArrows", e.target.checked)}
          />
        </label>
        <label className="flex items-center justify-between">
          <span>Eval bar</span>
          <input
            type="checkbox"
            checked={b.showEvalBar}
            onChange={(e) => update("showEvalBar", e.target.checked)}
          />
        </label>
        <label className="flex items-center justify-between">
          <span>Sounds</span>
          <input
            type="checkbox"
            checked={b.soundEnabled}
            onChange={(e) => update("soundEnabled", e.target.checked)}
          />
        </label>
      </div>

      <button
        onClick={reset}
        className="w-full rounded-md border border-[#2a303b] py-2 text-xs text-[#99a2b3] hover:border-[#6ea8fe] hover:text-white"
      >
        Reset all settings to default
      </button>
    </div>
  );
}
TSXEOF

cat > frontend/src/components/CoachPanel.tsx << 'TSXEOF'
"use client";

import { useRef, useState } from "react";
import type { Move } from "chess.js";
import { streamCoachChat } from "@/lib/api";
import { useSettings } from "@/lib/store";
import type { AnalysisResult, ChatUiMessage, CoachContext } from "@/lib/types";

const uid = () =>
  typeof crypto !== "undefined" && typeof crypto.randomUUID === "function"
    ? crypto.randomUUID()
    : Math.random().toString(36).slice(2);

interface CoachPanelProps {
  fen: string;
  history: Move[];
  analysis: AnalysisResult | null;
  playerColor: "w" | "b";
  getPgn: () => string;
}

export default function CoachPanel({
  fen,
  history,
  analysis,
  playerColor,
  getPgn,
}: CoachPanelProps) {
  const { settings, setCoach } = useSettings();
  const [messages, setMessages] = useState<ChatUiMessage[]>([]);
  const [input, setInput] = useState("");
  const [busy, setBusy] = useState(false);
  const scrollRef = useRef<HTMLDivElement>(null);

  const scrollToBottom = () => {
    if (scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
    }
  };

  const send = async (text: string) => {
    if (!text.trim() || busy) return;
    const userMsg: ChatUiMessage = {
      id: uid(),
      role: "user",
      content: text.trim(),
      createdAt: Date.now(),
    };
    const assistantId = uid();
    const assistantMsg: ChatUiMessage = {
      id: assistantId,
      role: "assistant",
      content: "",
      streaming: true,
      createdAt: Date.now(),
    };
    setMessages((m) => [...m, userMsg, assistantMsg]);
    setInput("");
    setBusy(true);

    const last = history[history.length - 1];
    const lastBefore = history[history.length - 2];
    const context: CoachContext = {
      fen,
      pgn: getPgn() || null,
      lastMoves: history.map((m) => m.san),
      playerColor,
      playerRating: settings.coach.playerRating,
      language: settings.coach.language,
      fenBefore: lastBefore?.after ?? null,
      lastMoveSan: last?.san ?? null,
      analysis,
      extraContext: null,
    };

    try {
      for await (const ev of streamCoachChat({
        messages: [...messages, userMsg].map((m) => ({
          role: m.role as "user" | "assistant",
          content: m.content,
        })),
        context,
        params: settings.engine,
        model: settings.coach.model,
        temperature: settings.coach.temperature,
        stream: true,
      })) {
        if (ev.error) {
          setMessages((m) =>
            m.map((x) =>
              x.id === assistantId
                ? { ...x, content: "⚠ " + ev.error, streaming: false, error: true }
                : x
            )
          );
          break;
        }
        if (ev.delta) {
          setMessages((m) =>
            m.map((x) =>
              x.id === assistantId
                ? { ...x, content: x.content + ev.delta }
                : x
            )
          );
          scrollToBottom();
        }
        if (ev.done) {
          setMessages((m) =>
            m.map((x) => (x.id === assistantId ? { ...x, streaming: false } : x))
          );
          break;
        }
      }
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      setMessages((m) =>
        m.map((x) =>
          x.id === assistantId
            ? { ...x, content: "⚠ " + msg, streaming: false, error: true }
            : x
        )
      );
    } finally {
      setBusy(false);
    }
  };

  const quick = [
    "Explain the last move.",
    "What is my plan here?",
    "Any tactical ideas?",
    "What should I focus on?",
  ];

  return (
    <div className="flex h-full min-h-0 flex-col p-3 text-sm">
      <div className="mb-2 rounded-md border border-[#2a303b] bg-[#161a21] p-2 text-xs">
        <label className="block">
          <span className="text-[#99a2b3]">Model</span>
          <input
            className="mt-1 w-full rounded-md border border-[#2a303b] bg-[#1d222b] px-2 py-1"
            value={settings.coach.model}
            onChange={(e) => setCoach({ model: e.target.value })}
          />
        </label>
        <label className="mt-2 block">
          <span className="text-[#99a2b3]">
            Your rating: {settings.coach.playerRating}
          </span>
          <input
            type="range"
            min={400}
            max={2400}
            step={100}
            value={settings.coach.playerRating}
            onChange={(e) =>
              setCoach({ playerRating: Number(e.target.value) })
            }
          />
        </label>
      </div>

      <div
        ref={scrollRef}
        className="flex-1 space-y-2 overflow-auto rounded-md border border-[#2a303b] bg-[#161a21] p-2"
      >
        {messages.length === 0 && (
          <div className="text-xs text-[#99a2b3]">
            Ask anything. The coach reads the engine lines and the position — it
            will not invent moves.
          </div>
        )}
        {messages.map((m) => (
          <div
            key={m.id}
            className={`whitespace-pre-wrap rounded-lg px-3 py-2 text-[13px] leading-relaxed ${
              m.role === "user"
                ? "ml-6 bg-[#4d6bfe]/20"
                : "mr-6 bg-[#1d222b]"
            } ${m.error ? "text-red-300" : ""}`}
          >
            {m.content || (m.streaming ? "…" : "")}
            {m.streaming && <span className="dot-pulse ml-1">▍</span>}
          </div>
        ))}
      </div>

      <div className="mt-2 flex flex-wrap gap-1">
        {quick.map((q) => (
          <button
            key={q}
            onClick={() => send(q)}
            className="rounded border border-[#2a303b] px-2 py-1 text-xs text-[#99a2b3] hover:border-[#6ea8fe] hover:text-white disabled:opacity-40"
            disabled={busy}
          >
            {q}
          </button>
        ))}
      </div>

      <form
        onSubmit={(e) => {
          e.preventDefault();
          void send(input);
        }}
        className="mt-2 flex gap-2"
      >
        <input
          value={input}
          onChange={(e) => setInput(e.target.value)}
          placeholder="Ask your coach…"
          className="flex-1 rounded-md border border-[#2a303b] bg-[#1d222b] px-3 py-2 text-sm outline-none focus:border-[#6ea8fe]"
          disabled={busy}
        />
        <button
          type="submit"
          disabled={busy || !input.trim()}
          className="rounded-md bg-[#4d6bfe] px-3 py-2 text-sm font-medium disabled:opacity-40"
        >
          Send
        </button>
      </form>
    </div>
  );
}
TSXEOF

echo ""
echo "✓ bootstrap-09 done. Files:"
find frontend/src/components -type f | sort
echo ""
echo "Line counts:"
wc -l frontend/src/components/*.tsx
echo ""
echo "Next: bootstrap-10 (ReviewPanel + page.tsx) — final script, app runs after this"
