/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  experimental: {
    // No native @next/swc-android-arm64 exists for Next 14 — use WASM.
    useWasmBinary: true,
  },
};

export default nextConfig;
