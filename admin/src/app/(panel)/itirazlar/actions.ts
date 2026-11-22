"use server";

import { refresh } from "next/cache";
import type { ActionState } from "@/components/ui";
import { dbErrorMessage } from "@/lib/errors";
import { createClient } from "@/lib/supabase/server";

type Decision = "confirmed" | "changed" | "cancelled";

// resolve_social_dispute: kullanici_bahsi_denetle izni (okulda) ister; bahsin hakemi ya da ona
// yatırım yapan karar veremez. Değiştirme ve iptal hakeme ihtar yazar. Karar denetim kaydına gider.
export async function resolveDispute(_prev: ActionState, formData: FormData): Promise<ActionState> {
  const decision = String(formData.get("decision") ?? "") as Decision;
  const optionId = String(formData.get("option_id") ?? "");
  if (!["confirmed", "changed", "cancelled"].includes(decision)) return { error: "Karar seç." };
  if (decision === "changed" && !optionId) return { error: "Doğru sonucu seç." };

  const supabase = await createClient();
  const { error } = await supabase.rpc("resolve_social_dispute", {
    p_bet_id: String(formData.get("bet_id") ?? ""),
    p_decision: decision,
    p_note: String(formData.get("note") ?? "").trim(),
    ...(decision === "changed" ? { p_option_id: optionId } : {}),
  });
  if (error) return { error: dbErrorMessage(error) };
  refresh();
  return { message: "Karar uygulandı." };
}
