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
