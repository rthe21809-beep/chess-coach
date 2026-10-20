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
