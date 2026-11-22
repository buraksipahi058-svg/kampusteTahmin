import type { Database } from "@/lib/supabase/database.types";

export type QuestPeriod = Database["public"]["Enums"]["quest_period"];
export type QuestAction = Database["public"]["Enums"]["quest_action"];
export type Currency = Database["public"]["Enums"]["currency"];

export type Quest = {
  id: string;
  school_id: string | null;
  title: string;
  description: string | null;
  period: QuestPeriod;
  action: QuestAction;
  target: number;
  reward_currency: Currency;
  reward_amount: number;
  reward_xp: number;
  starts_at: string | null;
  ends_at: string | null;
  active: boolean;
};

export const periodLabels: Record<QuestPeriod, string> = {
  daily: "Günlük",
  weekly: "Haftalık",
  seasonal: "Sezonluk",
};

export const periodHints: Record<QuestPeriod, string> = {
  daily: "her gün (İstanbul gece yarısı) yeniden",
  weekly: "her hafta (pazartesi) yeniden",
  seasonal: "başlangıç–bitiş arasında bir kez",
};

// İlerleme sunucuda mevcut kayıtlardan sayılır (bkz. private.quest_progress).
export const actionLabels: Record<QuestAction, string> = {
  wager: "Bahse katıl (resmi, sosyal, günün tahmini)",
  prediction: "Günün tahminine katıl",
  duel: "Trivia düellosu oyna",
  social_bet: "Sosyal bahis aç",
  win: "Bahis ya da düello kazan (ödeme > yatırım)",
};
