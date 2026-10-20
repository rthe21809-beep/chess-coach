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
