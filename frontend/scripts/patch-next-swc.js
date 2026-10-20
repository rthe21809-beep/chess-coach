// Force Next.js to load the WASM SWC binding on Android/Termux.
// Next 14 does not publish @next/swc-android-arm64, so the default
// "download native binary" path 404s. This flips the fallback order.
const fs = require("fs");
const path = require("path");

const file = path.join(process.cwd(), "node_modules/next/dist/build/swc/index.js");

if (!fs.existsSync(file)) {
  console.log("[patch-next-swc] next not installed — skipping");
  process.exit(0);
}

let src = fs.readFileSync(file, "utf8");

const replacement =
  'const shouldLoadWasmFallbackFirst = process.platform === "android" || (!disableWasmFallback && unsupportedPlatform && useWasmBinary) || isWebContainer;';

if (src.includes(replacement)) {
  console.log("[patch-next-swc] already patched");
  process.exit(0);
}

const re = /const shouldLoadWasmFallbackFirst\s*=\s*[^;]+;/;
if (!re.test(src)) {
  console.warn("[patch-next-swc] pattern not found (Next version changed?)");
  process.exit(0);
}

src = src.replace(re, replacement);
fs.writeFileSync(file, src);
console.log("[patch-next-swc] patched: Android loads WASM SWC first");
