"use server";

import { refresh } from "next/cache";
import type { ActionState } from "@/components/ui";
import { dbErrorMessage } from "@/lib/errors";
import { createClient } from "@/lib/supabase/server";

// set_user_ban: yalnızca süperadmin; gerekçe denetim kaydına yazılır, profilde yalnızca yasak zamanı tutulur.
export async function setBan(_prev: ActionState, formData: FormData): Promise<ActionState> {
  const banned = formData.get("banned") === "on";
  const supabase = await createClient();
  const { error } = await supabase.rpc("set_user_ban", {
    p_user_id: String(formData.get("user_id") ?? ""),
    p_banned: banned,
    p_reason: String(formData.get("reason") ?? "").trim(),
  });
  if (error) return { error: dbErrorMessage(error) };
  refresh();
  return { message: banned ? "Kullanıcı yasaklandı; oturumları kapatıldı." : "Yasak kaldırıldı." };
}

// reset_referee_strikes: süperadmin ya da kişinin okulunda kullanici_bahsi_denetle; gerekçe zorunlu.
export async function resetStrikes(_prev: ActionState, formData: FormData): Promise<ActionState> {
  const supabase = await createClient();
  const { error } = await supabase.rpc("reset_referee_strikes", {
    p_user_id: String(formData.get("user_id") ?? ""),
    p_note: String(formData.get("note") ?? "").trim(),
  });
  if (error) return { error: dbErrorMessage(error) };
  refresh();
  return { message: "İhtarlar sıfırlandı." };
}
