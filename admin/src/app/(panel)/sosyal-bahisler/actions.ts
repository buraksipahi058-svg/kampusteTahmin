"use server";

import { refresh } from "next/cache";
import type { ActionState } from "@/components/ui";
import { dbErrorMessage } from "@/lib/errors";
import { createClient } from "@/lib/supabase/server";

// cancel_social_bet: moderatör (kullanici_bahsi_denetle) her zaman iptal edebilir; herkese iade edilir.
export async function cancelSocialBet(_prev: ActionState, formData: FormData): Promise<ActionState> {
  const reason = String(formData.get("reason") ?? "").trim();
  if (reason.length < 3) return { error: "İptal gerekçesi yaz (en az 3 karakter)." };
  const supabase = await createClient();
  const { error } = await supabase.rpc("cancel_social_bet", {
    p_bet_id: String(formData.get("bet_id") ?? ""),
    p_reason: reason,
  });
  if (error) return { error: dbErrorMessage(error) };
  refresh();
  return { message: "Bahis iptal edildi; yatırımlar iade edildi." };
}
