"use server";

import { refresh } from "next/cache";
import { redirect } from "next/navigation";
import QRCode from "qrcode";
import type { ActionState } from "@/components/ui";
import { dbErrorMessage } from "@/lib/errors";
import { istanbulLocalToIso } from "@/lib/format";
import { createClient } from "@/lib/supabase/server";
import type { CampusPeriod, CampusVerification, Currency } from "./labels";

const text = (formData: FormData, key: string) => String(formData.get(key) ?? "").trim();
// Üretilen RPC tipleri null kabul etmiyor görünür; veritabanı null bekler (yeni görev, kontenjansız, tarihsiz).
const nullable = <T,>(value: T | null) => value as unknown as T;

// save_campus_task: okulunda kampus_gorevi_yonet ya da süperadmin; SSP ödülü yalnızca süperadmin (veritabanı denetler).
export async function saveCampusTask(_prev: ActionState, formData: FormData): Promise<ActionState> {
  const id = text(formData, "id");
  const reward = Number(text(formData, "reward_amount"));
  const xp = Number(text(formData, "reward_xp") || "0");
  const quotaText = text(formData, "quota");
  const quota = quotaText ? Number(quotaText) : null;
  const rotation = Number(text(formData, "qr_rotation_seconds") || "0");
  const startsAt = text(formData, "starts_at");
  const endsAt = text(formData, "ends_at");
  if (!Number.isInteger(reward) || reward < 1 || reward > 1000) return { error: "Ödül 1 ile 1000 arasında olmalı." };
  if (!Number.isInteger(xp) || xp < 0 || xp > 500) return { error: "XP 0 ile 500 arasında olmalı." };
  if (quota !== null && (!Number.isInteger(quota) || quota < 1)) return { error: "Kontenjan en az 1 olmalı ya da boş bırakılmalı." };

  const supabase = await createClient();
  const { error } = await supabase.rpc("save_campus_task", {
    p_id: nullable<string>(id || null),
    p_school_id: text(formData, "school_id"),
    p_title: text(formData, "title"),
    p_description: text(formData, "description"),
    p_icon: text(formData, "icon"),
    p_verification: text(formData, "verification") as CampusVerification,
    p_period: text(formData, "period") as CampusPeriod,
    p_reward_currency: text(formData, "reward_currency") as Currency,
    p_reward_amount: reward,
    p_reward_xp: xp,
    p_quota: nullable<number>(quota),
    p_qr_rotation_seconds: rotation,
    p_starts_at: nullable<string>(startsAt ? istanbulLocalToIso(startsAt) : null),
    p_ends_at: nullable<string>(endsAt ? istanbulLocalToIso(endsAt) : null),
    p_active: id ? formData.get("active") === "on" : true,
  });
  if (error) return { error: dbErrorMessage(error) };
  if (id) redirect("/kampus-gorevleri");
  refresh();
  return { message: "Kampüs görevi eklendi; QR görevinde \"QR\" bağlantısından kodu yazdır ya da ekranda aç." };
}

export async function toggleCampusTask(_prev: ActionState, formData: FormData): Promise<ActionState> {
  const supabase = await createClient();
  const id = text(formData, "id");
  const { data: t, error: readError } = await supabase
    .from("campus_tasks")
    .select("school_id, title, description, icon, verification, period, reward_currency, reward_amount, reward_xp, quota, qr_rotation_seconds, starts_at, ends_at, active")
    .eq("id", id)
    .maybeSingle();
  if (readError || !t) return { error: "Görev bulunamadı." };
  const { error } = await supabase.rpc("save_campus_task", {
    p_id: id,
    p_school_id: t.school_id,
    p_title: t.title,
    p_description: t.description ?? "",
    p_icon: t.icon,
    p_verification: t.verification,
    p_period: t.period,
    p_reward_currency: t.reward_currency,
    p_reward_amount: t.reward_amount,
    p_reward_xp: t.reward_xp,
    p_quota: nullable<number>(t.quota),
    p_qr_rotation_seconds: t.qr_rotation_seconds,
    p_starts_at: nullable<string>(t.starts_at),
    p_ends_at: nullable<string>(t.ends_at),
    p_active: !t.active,
  });
  if (error) return { error: dbErrorMessage(error) };
  refresh();
  return { message: t.active ? "Görev kapatıldı." : "Görev açıldı." };
}

export async function resetCampusQr(_prev: ActionState, formData: FormData): Promise<ActionState> {
  const supabase = await createClient();
  const { error } = await supabase.rpc("reset_campus_task_qr", { p_task_id: text(formData, "id") });
  if (error) return { error: dbErrorMessage(error) };
  refresh();
  return { message: "QR yenilendi; eski (basılı) kod artık geçmez. Yenisini yazdır." };
}

export type QrView = { svg: string; code: string; rotationSeconds: number; validUntil: string | null } | { error: string };

// QR içeriğini (kod + uygulamanın okuduğu bağlantı) sunucuda alır ve SVG'ye çevirir. Anahtar hiç tarayıcıya gitmez.
export async function loadCampusQr(taskId: string): Promise<QrView> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("campus_task_qr", { p_task_id: taskId }).single();
  if (error || !data) return { error: error ? dbErrorMessage(error) : "Görev bulunamadı." };
  const svg = await QRCode.toString(data.payload, { type: "svg", errorCorrectionLevel: "M", margin: 2, width: 320 });
  return { svg, code: data.code, rotationSeconds: data.rotation_seconds, validUntil: data.valid_until };
}
