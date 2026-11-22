import type { NextConfig } from "next";

// Güvenlik başlıkları (Adım 12 güvenlik kontrolü): panel başka sitede çerçeve içinde açılamaz (tıklama
// kandırmacası), tarayıcı içerik türünü tahmin etmez, başka sitelere tam adres gitmez, cihaz izinleri kapalı.
// HTTPS zorunluluğu (HSTS) barındırma tarafında verilir.
const securityHeaders = [
  { key: "X-Frame-Options", value: "DENY" },
  { key: "Content-Security-Policy", value: "frame-ancestors 'none'" },
  { key: "X-Content-Type-Options", value: "nosniff" },
  { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
  { key: "Permissions-Policy", value: "camera=(), microphone=(), geolocation=()" },
];

const nextConfig: NextConfig = {
  cacheComponents: true,
  partialPrefetching: true,
  poweredByHeader: false,
  headers() {
    return [{ source: "/:path*", headers: securityHeaders }];
  },
  turbopack: {
    rules: {
      "*.css": {
        loaders: ["@tailwindcss/turbopack"],
        as: "*.css",
      },
    },
  },
};

export default nextConfig;
