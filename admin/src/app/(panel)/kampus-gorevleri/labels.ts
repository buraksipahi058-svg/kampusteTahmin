import type { Database } from "@/lib/supabase/database.types";

export type CampusVerification = Database["public"]["Enums"]["campus_verification"];
export type CampusPeriod = Database["public"]["Enums"]["campus_period"];
export type Currency = Database["public"]["Enums"]["currency"];

export type CampusTask = {
  id: string;
  school_id: string;
  title: string;
  description: string | null;
  icon: string;
  verification: CampusVerification;
  period: CampusPeriod;
  reward_currency: Currency;
  reward_amount: number;
  reward_xp: number;
  quota: number | null;
  qr_rotation_seconds: number;
  starts_at: string | null;
  ends_at: string | null;
  active: boolean;
};

/** Ödül üst sınırı: süperadmin 1000 SP / 500 XP; yetkili ekonomi ayarındaki tavan (veritabanı da denetler). */
export type RewardLimits = { sp: number; xp: number };

export const verificationLabels: Record<CampusVerification, string> = {
  qr: "QR kod (okutunca hemen ödül)",
  photo: "Fotoğraf (yetkili onaylar)",
};

export const periodLabels: Record<CampusPeriod, string> = {
  once: "Bir kez",
  daily: "Her gün",
  weekly: "Her hafta",
};

// 0: basılı QR (kod sabit; sızarsa "QR'ı yenile"). Diğerleri: mekândaki ekranda dönen QR.
export const rotationLabels: Record<number, string> = {
  0: "Basılı QR (sabit kod)",
  30: "Ekranda, 30 sn'de bir değişir",
  60: "Ekranda, 1 dk'da bir değişir",
  120: "Ekranda, 2 dk'da bir değişir",
  300: "Ekranda, 5 dk'da bir değişir",
};
