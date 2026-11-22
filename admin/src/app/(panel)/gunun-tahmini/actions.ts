"use server";

import { refresh } from "next/cache";
import type { ActionState } from "@/components/ui";
import { dbErrorMessage } from "@/lib/errors";
import { istanbulLocalToIso } from "@/lib/format";
import { createClient } from "@/lib/supabase/server";

const text = (formData: FormData, key: string) => String(formData.get(key) ?? "").trim();

// Yetki kontrolü veritabanındaki fonksiyonlardadır (açma resmi_bahis_ac, sonuç / iptal resmi_bahis_kapat).

export async function createDailyPrediction(_prev: ActionState, formData: FormData): Promise<ActionState> {
  const locksAt = text(formData, "locks_at");
  if (!locksAt) return { error: "Kapanış zamanı seç." };

  const supabase = await createClient();
  const description = text(formData, "description");
  const { error } = await supabase.rpc("create_daily_prediction", {
    p_school_id: text(formData, "school_id"),
    p_question: text(formData, "question"),
    p_locks_at: istanbulLocalToIso(locksAt),
    ...(description ? { p_description: description } : {}),
  });
  if (error) return { error: dbErrorMessage(error) };
  refresh();
  return { message: "Günün tahmini açıldı; öğrenciler uygulamada Oyunlar sekmesinde görür." };
}

export async function settleDailyPrediction(_prev: ActionState, formData: FormData): Promise<ActionState> {
  const winner = text(formData, "winning_option_id");
  if (!winner) return { error: "Sonucu seç." };
  const supabase = await createClient();
  const { error } = await supabase.rpc("settle_daily_prediction", {
    p_bet_id: text(formData, "bet_id"),
    p_winning_option_id: winner,
  });
  if (error) return { error: dbErrorMessage(error) };
  refresh();
  return { message: "Sonuç girildi, havuz dağıtıldı." };
}

export async function cancelDailyPrediction(_prev: ActionState, formData: FormData): Promise<ActionState> {
  const supabase = await createClient();
  const { error } = await supabase.rpc("cancel_daily_prediction", {
    p_bet_id: text(formData, "bet_id"),
    p_reason: text(formData, "reason"),
  });
  if (error) return { error: dbErrorMessage(error) };
  refresh();
  return { message: "Tahmin iptal edildi, yatırımlar iade edildi." };
}
