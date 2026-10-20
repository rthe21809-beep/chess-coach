"use client";

import { evalToPercent, formatEval } from "@/lib/format";
import type { AnalysisResult } from "@/lib/types";

export default function EvalBar({
  analysis,
}: {
  analysis: AnalysisResult | null;
}) {
  const line = analysis?.lines[0] ?? null;
  const whitePct = evalToPercent(line);
  const label = formatEval(line);

  return (
    <div className="relative flex h-full w-7 flex-col overflow-hidden rounded-md border border-[#2a303b] bg-[#161a21]">
      <div
        className="bg-[#e8ebf1] transition-[height] duration-300"
        style={{ height: `${whitePct}%` }}
      />
      <div className="flex-1 bg-[#1d222b]" />
      <div className="absolute inset-x-0 top-1 text-center text-[10px] font-semibold text-black/70">
        {whitePct > 8 ? label : ""}
      </div>
    </div>
  );
}
