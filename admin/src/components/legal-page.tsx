import type { ReactNode } from "react";
import type { LegalBlock } from "@/lib/legal";

// Herkese açık metin sayfaları (gizlilik, kullanım koşulları, hesap silme): oturum istemez, mağaza bağlantısı olarak verilir.
export function LegalPage({ blocks, children }: { blocks: LegalBlock[]; children?: ReactNode }) {
  return (
    <main className="mx-auto w-full max-w-2xl px-4 py-10 text-sm leading-6">
      {blocks.map((block, i) => {
        switch (block.kind) {
          case "title":
            return (
              <h1 key={i} className="mb-3 text-2xl font-semibold">
                {block.text}
              </h1>
            );
          case "heading":
            return (
              <h2 key={i} className="mt-6 mb-2 text-lg font-semibold">
                {block.text}
              </h2>
            );
          case "list":
            return (
              <ul key={i} className="mb-3 list-disc space-y-1 pl-5">
                {block.items.map((item, j) => (
                  <li key={j}>{item}</li>
                ))}
              </ul>
            );
          default:
            return (
              <p key={i} className="mb-3">
                {block.text}
              </p>
            );
        }
      })}
      {children}
    </main>
  );
}
