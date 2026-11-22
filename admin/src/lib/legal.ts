import { readFile } from "node:fs/promises";
import path from "node:path";

// KVKK aydınlatma metni ve kullanım koşulları: mobildeki `mobile/assets/legal/*.txt` ile aynı kopyalar
// (`src/legal/`); aynılığı mobil test denetler (mobile/test/app_info_test.dart).
// Biçim: "# " başlık, "## " ara başlık, "- " madde; diğer satırlar paragraf.

export type LegalBlock =
  | { kind: "title" | "heading" | "paragraph"; text: string }
  | { kind: "list"; items: string[] };

export async function readPrivacyNotice(): Promise<string> {
  "use cache";
  return readFile(path.join(process.cwd(), "src/legal/kvkk_aydinlatma.txt"), "utf8");
}

export async function readTermsOfUse(): Promise<string> {
  "use cache";
  return readFile(path.join(process.cwd(), "src/legal/kullanim_kosullari.txt"), "utf8");
}

export function parseLegalText(text: string): LegalBlock[] {
  const blocks: LegalBlock[] = [];
  for (const raw of text.split(/\r?\n/)) {
    const line = raw.trimEnd();
    if (!line) continue;
    if (line.startsWith("# ")) blocks.push({ kind: "title", text: line.slice(2) });
    else if (line.startsWith("## ")) blocks.push({ kind: "heading", text: line.slice(3) });
    else if (line.startsWith("- ")) {
      const last = blocks.at(-1);
      if (last?.kind === "list") last.items.push(line.slice(2));
      else blocks.push({ kind: "list", items: [line.slice(2)] });
    } else blocks.push({ kind: "paragraph", text: line });
  }
  return blocks;
}
