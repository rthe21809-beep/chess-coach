#!/usr/bin/env bash
# bootstrap-05.sh — frontend scaffold: package.json, tsconfig, tailwind, layout, globals.css
set -euo pipefail

mkdir -p frontend/src/app frontend/src/lib frontend/src/hooks frontend/src/components

echo "→ bootstrap-05: frontend scaffold"

cat > frontend/package.json << 'JSONEOF'
{
  "name": "chess-coach-frontend",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "dev": "next dev -H 127.0.0.1 -p 3000",
    "build": "next build",
    "start": "next start -H 127.0.0.1 -p 3000",
    "typecheck": "tsc --noEmit"
  },
  "dependencies": {
    "chess.js": "1.0.0-beta.8",
    "framer-motion": "^11.11.9",
    "next": "14.2.15",
    "react": "^18.3.1",
    "react-chessboard": "^4.7.2",
    "react-dom": "^18.3.1",
    "zustand": "^4.5.5"
  },
  "devDependencies": {
    "@types/node": "^20.16.11",
    "@types/react": "^18.3.11",
    "@types/react-dom": "^18.3.0",
    "autoprefixer": "^10.4.20",
    "postcss": "^8.4.47",
    "tailwindcss": "^3.4.13",
    "typescript": "^5.6.3"
  }
}
JSONEOF

cat > frontend/tsconfig.json << 'JSONEOF'
{
  "compilerOptions": {
    "target": "ES2020",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "plugins": [{ "name": "next" }],
    "paths": { "@/*": ["./src/*"] }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
JSONEOF

cat > frontend/next-env.d.ts << 'TSEOF'
/// <reference types="next" />
/// <reference types="next/image-types/global" />
TSEOF

cat > frontend/postcss.config.mjs << 'JSEOF'
export default { plugins: { tailwindcss: {}, autoprefixer: {} } };
JSEOF

cat > frontend/tailwind.config.ts << 'TSEOF'
import type { Config } from "tailwindcss";

const config: Config = {
  content: ["./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      fontFamily: {
        sans: ["ui-sans-serif", "system-ui", "-apple-system", "Segoe UI", "Roboto", "sans-serif"],
        mono: ["ui-monospace", "SFMono-Regular", "Menlo", "monospace"],
      },
    },
  },
  plugins: [],
};

export default config;
TSEOF

cat > frontend/next.config.mjs << 'JSEOF'
/** @type {import('next').NextConfig} */
const nextConfig = { reactStrictMode: true };
export default nextConfig;
JSEOF

cat > frontend/.env.local.example << 'ENVEOF'
NEXT_PUBLIC_API_BASE=http://127.0.0.1:8000
ENVEOF

cat > frontend/src/app/globals.css << 'CSSEOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

:root {
  --bg: #0f1115;
  --panel: #161a21;
  --panel-2: #1d222b;
  --border: #2a303b;
  --text: #e8ebf1;
  --muted: #99a2b3;
  --accent: #6ea8fe;
}

* { box-sizing: border-box; }
html, body { padding: 0; margin: 0; min-height: 100%; }
body {
  background: radial-gradient(1200px 600px at 50% -10%, #182031 0%, transparent 60%), var(--bg);
  color: var(--text);
  -webkit-tap-highlight-color: transparent;
  font-feature-settings: "tnum" 1;
}
::selection { background: rgba(110, 168, 254, 0.35); }

* { scrollbar-width: thin; scrollbar-color: #333b48 transparent; }
*::-webkit-scrollbar { width: 8px; height: 8px; }
*::-webkit-scrollbar-thumb { background: #333b48; border-radius: 8px; }

input[type="range"] {
  -webkit-appearance: none; appearance: none;
  width: 100%; height: 22px; background: transparent;
}
input[type="range"]::-webkit-slider-runnable-track {
  height: 4px; border-radius: 999px; background: #2d3442;
}
input[type="range"]::-webkit-slider-thumb {
  -webkit-appearance: none; appearance: none;
  margin-top: -6px; width: 16px; height: 16px; border-radius: 50%;
  background: var(--accent); border: 2px solid #0f1115;
}

input[type="color"] {
  -webkit-appearance: none; appearance: none;
  border: 1px solid var(--border); border-radius: 8px;
  width: 40px; height: 28px; background: transparent; padding: 0; cursor: pointer;
}
input[type="color"]::-webkit-color-swatch-wrapper { padding: 2px; }
input[type="color"]::-webkit-color-swatch { border: none; border-radius: 6px; }

@keyframes pulse-dot {
  0%, 100% { opacity: 0.25; transform: scale(0.85); }
  50% { opacity: 1; transform: scale(1); }
}
.dot-pulse { animation: pulse-dot 1.1s ease-in-out infinite; }
CSSEOF

cat > frontend/src/app/layout.tsx << 'TSXEOF'
import type { Metadata, Viewport } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Chess Coach",
  description: "Local chess app with adjustable bots and an LLM coach",
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  maximumScale: 1,
  themeColor: "#0f1115",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body className="min-h-screen antialiased">{children}</body>
    </html>
  );
}
TSXEOF

echo ""
echo "✓ bootstrap-05 done. Files:"
find frontend -type f -not -path '*/node_modules/*' | sort
echo ""
echo "Next: bootstrap-06 (lib/ + hooks/)"
