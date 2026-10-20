"use client";

import { useState } from "react";
import { streamReview } from "@/lib/api";
import { useSettings } from "@/lib/store";
import { classifyColor, classifyIcon, formatAccuracy } from "@/lib/format";
import type { GameReview } from "@/lib/types";

interface ReviewPanelProps {
  pgn: string;
}

export default function ReviewPanel({ pgn }: ReviewPanelProps) {
  const { settings } = useSettings();
  const [review, setReview] = useState<GameReview | null>(null);
  const [progress, setProgress] = useState<{ done: number; total: number } | null>(
    null
  );
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const start = async () => {
    if (!pgn || busy) return;
    setBusy(true);
    setError(null);
    setReview(null);
    setProgress(null);
    try {
      for await (const ev of streamReview(
        pgn,
        settings.engine,
        Math.min(12, settings.engine.depth)
      )) {
        if (ev.kind === "progress") setProgress(ev.data);
        else if (ev.kind === "result") setReview(ev.data);
        else if (ev.kind === "error") {
          setError(ev.message);
          break;
        }
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="space-y-3 p-3 text-sm">
      <button
        onClick={start}
        disabled={busy || !pgn}
        className="w-full rounded-md bg-[#4d6bfe] py-2 font-medium disabled:opacity-40"
      >
        {busy ? "Reviewing…" : "Review this game"}
      </button>

      {!pgn && (
        <div className="text-xs text-[#99a2b3]">Play a game first.</div>
      )}

      {progress && busy && (
        <div className="rounded-md border border-[#2a303b] bg-[#161a21] p-2 text-xs">
          <div className="flex justify-between">
            <span>Analyzing</span>
            <span className="font-mono">
              {progress.done}/{progress.total}
            </span>
          </div>
          <div className="mt-1 h-1.5 overflow-hidden rounded bg-[#1d222b]">
            <div
              className="h-full bg-[#6ea8fe] transition-[width]"
              style={{
                width: `${(progress.done / Math.max(1, progress.total)) * 100}%`,
              }}
            />
          </div>
        </div>
      )}

      {error && (
        <div className="rounded-md border border-red-500/30 bg-red-500/5 p-2 text-xs text-red-300">
          {error}
        </div>
      )}

      {review && (
        <div className="space-y-3">
          <div className="grid grid-cols-2 gap-2">
            {(["white", "black"] as const).map((side) => {
              const acc =
                side === "white" ? review.whiteAccuracy : review.blackAccuracy;
              const acpl =
                side === "white" ? review.whiteAcpl : review.blackAcpl;
              return (
                <div
                  key={side}
                  className="rounded-md border border-[#2a303b] bg-[#161a21] p-2"
                >
                  <div className="text-xs uppercase text-[#99a2b3]">{side}</div>
                  <div className="text-lg font-semibold">
                    {formatAccuracy(acc)}
                  </div>
                  <div className="text-xs text-[#99a2b3]">
                    ACPL {acpl.toFixed(0)}
                  </div>
                </div>
              );
            })}
          </div>

          <div className="rounded-md border border-[#2a303b] bg-[#161a21] p-2">
            <div className="mb-1 text-xs uppercase text-[#99a2b3]">
              {review.opening ?? "Game"}
            </div>
            <div className="grid grid-cols-2 gap-x-3 gap-y-1 text-xs">
              {(Object.keys(review.counts) as (keyof typeof review.counts)[]).map(
                (k) => {
                  const c = review.counts[k];
                  if (c.w + c.b === 0) return null;
                  return (
                    <div key={k} className="contents">
                      <span className={classifyColor(k)}>
                        {classifyIcon(k)} {k}
                      </span>
                      <span className="font-mono text-[#99a2b3]">
                        {c.w}·{c.b}
                      </span>
                    </div>
                  );
                }
              )}
            </div>
          </div>

          <div className="max-h-72 overflow-auto rounded-md border border-[#2a303b] bg-[#161a21] p-1">
            <table className="w-full text-xs font-mono">
              <thead className="sticky top-0 bg-[#161a21] text-[#99a2b3]">
                <tr>
                  <th className="p-1 text-left">#</th>
                  <th className="p-1 text-left">Move</th>
                  <th className="p-1 text-left">Eval</th>
                  <th className="p-1 text-left">Class</th>
                </tr>
              </thead>
              <tbody>
                {review.moves.map((mv) => (
                  <tr key={mv.ply} className="border-t border-[#222933]">
                    <td className="p-1 text-[#99a2b3]">
                      {mv.moveNumber}
                      {mv.color === "w" ? "." : "…"}
                    </td>
                    <td className="p-1">{mv.san}</td>
                    <td className="p-1">
                      {(mv.evalAfterCp ?? 0) >= 0 ? "+" : ""}
                      {((mv.evalAfterCp ?? 0) / 100).toFixed(2)}
                    </td>
                    <td className={`p-1 ${classifyColor(mv.classification)}`}>
                      {classifyIcon(mv.classification)} {mv.classification}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
}
