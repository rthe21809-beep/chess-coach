"use client";

import type { Move } from "chess.js";

export default function MoveList({ history }: { history: Move[] }) {
  const rows: { n: number; w?: Move; b?: Move }[] = [];
  for (let i = 0; i < history.length; i += 2) {
    rows.push({ n: i / 2 + 1, w: history[i], b: history[i + 1] });
  }
  if (rows.length === 0) {
    return (
      <div className="mt-3 rounded-md border border-[#2a303b] bg-[#161a21] p-3 text-xs text-[#99a2b3]">
        No moves yet.
      </div>
    );
  }
  return (
    <div className="mt-3 max-h-48 overflow-auto rounded-md border border-[#2a303b] bg-[#161a21] p-2 text-sm">
      <div className="grid grid-cols-[auto_1fr_1fr] gap-x-3 gap-y-1 font-mono">
        {rows.map((r) => (
          <div key={r.n} className="contents">
            <span className="text-[#99a2b3]">{r.n}.</span>
            <span>{r.w?.san ?? ""}</span>
            <span>{r.b?.san ?? ""}</span>
          </div>
        ))}
      </div>
    </div>
  );
}
