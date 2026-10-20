// Formatting helpers for evals, classifications, and numbers.

export function formatEval(
  line?: { scoreCp: number | null; mate: number | null } | null,
  perspective: "white" | "black" = "white"
): string {
  if (!line) return "—";
  if (line.mate !== null && line.mate !== undefined) {
    const v = perspective === "white" ? line.mate : -line.mate;
    return `${v > 0 ? "+" : "-"}M${Math.abs(line.mate)}`;
  }
  if (line.scoreCp === null || line.scoreCp === undefined) return "—";
  const cp = perspective === "white" ? line.scoreCp : -line.scoreCp;
  return `${cp >= 0 ? "+" : ""}${(cp / 100).toFixed(2)}`;
}

export function evalToPercent(
  line?: { scoreCp: number | null; mate: number | null } | null
): number {
  if (!line) return 50;
  if (line.mate !== null && line.mate !== undefined) return line.mate > 0 ? 100 : 0;
  const cp = Math.max(-1200, Math.min(1200, line.scoreCp ?? 0));
  return 50 + 50 * (2 / (1 + Math.exp(-0.00368208 * cp)) - 1);
}

export function classifyColor(cls: string): string {
  switch (cls) {
    case "brilliant": return "text-cyan-300";
    case "great": return "text-blue-300";
    case "best": return "text-emerald-300";
    case "excellent": return "text-green-300";
    case "good": return "text-slate-300";
    case "book": return "text-amber-300";
    case "inaccuracy": return "text-yellow-300";
    case "mistake": return "text-orange-300";
    case "blunder": return "text-red-400";
    case "miss": return "text-pink-400";
    default: return "text-slate-300";
  }
}

export function classifyIcon(cls: string): string {
  switch (cls) {
    case "brilliant": return "!!";
    case "great": return "!";
    case "best": return "★";
    case "excellent": return "✓";
    case "good": return "·";
    case "book": return "📖";
    case "inaccuracy": return "?!";
    case "mistake": return "?";
    case "blunder": return "??";
    case "miss": return "✗";
    default: return "";
  }
}

export function formatNodes(n: number): string {
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
  if (n >= 1_000) return `${(n / 1_000).toFixed(0)}k`;
  return String(n);
}

export function formatAccuracy(a: number): string {
  return `${a.toFixed(1)}%`;
}
