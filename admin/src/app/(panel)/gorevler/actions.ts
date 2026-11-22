"use server";

import { refresh } from "next/cache";
import { redirect } from "next/navigation";
import type { ActionState } from "@/components/ui";
import { dbErrorMessage } from "@/lib/errors";
import { istanbulLocalToIso } from "@/lib/format";
import { createClient } from "@/lib/supabase/server";
import type { Currency, QuestAction, QuestPeriod } from "./labels";

const text = (formData: FormData, key: string) => String(formData.get(key) ?? "").trim();
// Üretilen RPC tipleri null kabul etmiyor görünür; veritabanı null'u (genel görev, tarihsiz) bekler.
const nullable = (value: string) => (value || null) as unknown as string;

// save_quest: okul görevi gorev_yonet; genel görev ve SSP ödülü yalnızca süperadmin (veritabanı denetler).

export async function saveQuest(_prev: ActionState, formData: FormData): Promise<ActionState> {
  const id = text(formData, "id");
  const target = Number(text(formData, "target"));
  const reward = Number(text(formData, "reward_amount"));
  const startsAt = text(formData, "starts_at");
  const endsAt = text(formData, "ends_at");
  if (!Number.isInteger(target) || target < 1) return { error: "Hedef en az 1 olmalı." };
  if (!Number.isInteger(reward) || reward < 1) return { error: "Ödül en az 1 olmalı." };

  const supabase = await createClient();
  const { error } = await supabase.rpc("save_quest", {
    p_id: nullable(id),
    p_school_id: nullable(text(formData, "school_id")),
    p_title: text(formData, "title"),
    p_description: text(formData, "description"),
    p_period: text(formData, "period") as QuestPeriod,
    p_action: text(formData, "action") as QuestAction,
    p_target: target,
    p_reward_currency: text(formData, "reward_currency") as Currency,
    p_reward_amount: reward,
    p_starts_at: nullable(startsAt && istanbulLocalToIso(startsAt)),
    p_ends_at: nullable(endsAt && istanbulLocalToIso(endsAt)),
    p_active: id ? formData.get("active") === "on" : true,
  });
  if (error) return { error: dbErrorMessage(error) };
  if (id) redirect("/gorevler");
  refresh();
  return { message: "Görev eklendi; öğrenciler uygulamada Profil > Görevler'de görür." };
}

export async function toggleQuest(_prev: ActionState, formData: FormData): Promise<ActionState> {
  const supabase = await createClient();
  const id = text(formData, "id");
  const { data: q, error: readError } = await supabase
    .from("quests")
    .select("school_id, title, description, period, action, target, reward_currency, reward_amount, starts_at, ends_at, active")
    .eq("id", id)
    .maybeSingle();
  if (readError || !q) return { error: "Görev bulunamadı." };

  const { error } = await supabase.rpc("save_quest", {
    p_id: id,
    p_school_id: q.school_id as string,
    p_title: q.title,
    p_description: q.description ?? "",
    p_period: q.period,
    p_action: q.action,
    p_target: q.target,
    p_reward_currency: q.reward_currency,
    p_reward_amount: q.reward_amount,
    p_starts_at: q.starts_at as string,
    p_ends_at: q.ends_at as string,
    p_active: !q.active,
  });
  if (error) return { error: dbErrorMessage(error) };
  refresh();
  return { message: q.active ? "Görev kapatıldı." : "Görev açıldı." };
}
