"use server";

import { refresh } from "next/cache";
import { redirect } from "next/navigation";
import type { ActionState } from "@/components/ui";
import { dbErrorMessage } from "@/lib/errors";
import { createClient } from "@/lib/supabase/server";
import type { AchievementCategory } from "./labels";

const text = (formData: FormData, key: string) => String(formData.get(key) ?? "").trim();
// Üretilen RPC tipleri null kabul etmiyor görünür; veritabanı yeni başarımda null id bekler.
const nullable = (value: string) => (value || null) as unknown as string;

const int = (formData: FormData, key: string) => Number(text(formData, key));

// save_achievement: yalnızca süperadmin (veritabanı denetler). Anahtar sonradan değişmez.
export async function saveAchievement(_prev: ActionState, formData: FormData): Promise<ActionState> {
  const id = text(formData, "id");
  const key = text(formData, "key");
  const target = int(formData, "target");
  const tier = int(formData, "tier");
  const sp = int(formData, "reward_sp");
  const xp = int(formData, "reward_xp");
  const sort = int(formData, "sort");
  if (!/^[a-z0-9_]{3,40}$/.test(key)) return { error: "Anahtar 3-40 karakter: küçük harf, rakam, alt çizgi." };
  if (!Number.isInteger(target) || target < 1 || target > 100000) return { error: "Hedef 1 ile 100.000 arasında olmalı." };
  if (![1, 2, 3].includes(tier)) return { error: "Kademe bronz, gümüş ya da altın olmalı." };
  if (!Number.isInteger(sp) || sp < 1 || sp > 1000) return { error: "SP ödülü 1 ile 1000 arasında olmalı." };
  if (!Number.isInteger(xp) || xp < 0 || xp > 500) return { error: "XP 0 ile 500 arasında olmalı." };
  if (!Number.isInteger(sort)) return { error: "Sıra bir tam sayı olmalı." };

  const supabase = await createClient();
  const { error } = await supabase.rpc("save_achievement", {
    p_id: nullable(id),
    p_key: key,
    p_category: text(formData, "category") as AchievementCategory,
    p_title: text(formData, "title"),
    p_description: text(formData, "description"),
    p_icon: text(formData, "icon"),
    p_metric: text(formData, "metric"),
    p_target: target,
    p_tier: tier,
    p_reward_sp: sp,
    p_reward_xp: xp,
    p_hidden: formData.get("hidden") === "on",
    p_sort: sort,
    p_active: id ? formData.get("active") === "on" : true,
  });
  if (error) return { error: dbErrorMessage(error) };
  if (id) redirect("/basarimlar");
  refresh();
  return { message: "Başarım eklendi; öğrenciler uygulamada Profil > Başarımlar'da görür." };
}

export async function toggleAchievement(_prev: ActionState, formData: FormData): Promise<ActionState> {
  const supabase = await createClient();
  const id = text(formData, "id");
  const { data: a, error: readError } = await supabase
    .from("achievements")
    .select("key, category, title, description, icon, metric, target, tier, reward_sp, reward_xp, hidden, sort, active")
    .eq("id", id)
    .maybeSingle();
  if (readError || !a) return { error: "Başarım bulunamadı." };

  const { error } = await supabase.rpc("save_achievement", {
    p_id: id,
    p_key: a.key,
    p_category: a.category,
    p_title: a.title,
    p_description: a.description,
    p_icon: a.icon,
    p_metric: a.metric,
    p_target: a.target,
    p_tier: a.tier,
    p_reward_sp: a.reward_sp,
    p_reward_xp: a.reward_xp,
    p_hidden: a.hidden,
    p_sort: a.sort,
    p_active: !a.active,
  });
  if (error) return { error: dbErrorMessage(error) };
  refresh();
  return { message: a.active ? "Başarım kapatıldı (kazananlarda kalır)." : "Başarım açıldı." };
}
