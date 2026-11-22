"use server";

import { refresh } from "next/cache";
import { redirect } from "next/navigation";
import type { ActionState } from "@/components/ui";
import { dbErrorMessage } from "@/lib/errors";
import { istanbulLocalToIso } from "@/lib/format";
import { createClient } from "@/lib/supabase/server";

const text = (formData: FormData, key: string) => String(formData.get(key) ?? "").trim();

// Yetki kontrolü veritabanındaki fonksiyonlardadır (resmi_bahis_ac / resmi_bahis_kapat).

export async function createOfficialBet(_prev: ActionState, formData: FormData): Promise<ActionState> {
  const labels = formData.getAll("label").map((v) => String(v).trim());
  const odds = formData.getAll("odds").map((v) => Number(String(v).replace(",", ".")));
  const locksAt = text(formData, "locks_at");
  const maxStake = text(formData, "max_stake");

  if (labels.some((l) => !l)) return { error: "Seçenek adları boş olamaz." };
  if (odds.some((o) => !Number.isFinite(o))) return { error: "Oranlar sayı olmalı (ör. 1,85)." };
  if (!locksAt) return { error: "Kapanış zamanı seç." };

  const supabase = await createClient();
  const { error } = await supabase.rpc("create_official_bet", {
    p_school_id: text(formData, "school_id"),
    p_title: text(formData, "title"),
    p_description: text(formData, "description"),
    p_options: labels,
    p_odds: odds,
    p_locks_at: istanbulLocalToIso(locksAt),
    ...(maxStake ? { p_max_stake: Number(maxStake) } : {}),
  });
  if (error) return { error: dbErrorMessage(error) };
  redirect("/resmi-bahisler");
}

export async function lockBet(_prev: ActionState, formData: FormData): Promise<ActionState> {
  const supabase = await createClient();
  const { error } = await supabase.rpc("lock_official_bet", { p_bet_id: text(formData, "bet_id") });
  if (error) return { error: dbErrorMessage(error) };
  refresh();
  return { message: "Bahis kilitlendi; artık yatırım alınmıyor." };
}

export async function settleBet(_prev: ActionState, formData: FormData): Promise<ActionState> {
  const winner = text(formData, "winning_option_id");
  if (!winner) return { error: "Kazanan seçeneği seç." };
  const supabase = await createClient();
  const { error } = await supabase.rpc("settle_official_bet", {
    p_bet_id: text(formData, "bet_id"),
    p_winning_option_id: winner,
  });
  if (error) return { error: dbErrorMessage(error) };
  refresh();
  return { message: "Bahis sonuçlandı, ödemeler yapıldı." };
}

export async function cancelBet(_prev: ActionState, formData: FormData): Promise<ActionState> {
  const supabase = await createClient();
  const { error } = await supabase.rpc("cancel_official_bet", {
    p_bet_id: text(formData, "bet_id"),
    p_reason: text(formData, "reason"),
  });
  if (error) return { error: dbErrorMessage(error) };
  refresh();
  return { message: "Bahis iptal edildi, yatırımlar iade edildi." };
}

// update_official_bet_odds: açık sabit oranlı bahiste, açan okulun resmi_bahis_ac yetkilisi.
export async function updateOdds(_prev: ActionState, formData: FormData): Promise<ActionState> {
  const odds = formData.getAll("odds").map((v) => Number(String(v).replace(",", ".")));
  if (odds.some((o) => !Number.isFinite(o) || o < 1.01 || o > 20)) return { error: "Oranlar 1,01 ile 20,00 arasında olmalı." };
  const supabase = await createClient();
  const { error } = await supabase.rpc("update_official_bet_odds", { p_bet_id: text(formData, "bet_id"), p_odds: odds });
  if (error) return { error: dbErrorMessage(error) };
  refresh();
  return { message: "Oranlar güncellendi." };
}
