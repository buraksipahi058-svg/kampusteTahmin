import type { Database } from "@/lib/supabase/database.types";

export type AchievementCategory = Database["public"]["Enums"]["achievement_category"];

export type Achievement = {
  id: string;
  key: string;
  category: AchievementCategory;
  title: string;
  description: string;
  icon: string;
  metric: string;
  target: number;
  tier: number;
  reward_sp: number;
  reward_xp: number;
  hidden: boolean;
  sort: number;
  active: boolean;
};

export const categoryLabels: Record<AchievementCategory, string> = {
  progress: "Başlangıç ve ilerleme",
  prediction: "Tahmin",
  streak: "Seri",
  duel: "Düello",
  social: "Sosyal",
  loyalty: "Sadakat",
  secret: "Gizli",
};

export const tierLabels: Record<number, string> = { 1: "Bronz", 2: "Gümüş", 3: "Altın" };

// İlerleme sunucuda öğrencinin kayıtlarından hesaplanır (private.achievement_metrics); tüm zamanlar.
// Liste veritabanındaki `achievements.metric` kısıtıyla aynı olmalı.
export const metricLabels: Record<string, string> = {
  verified: "Okul maili doğrulandı (1)",
  predictions: "Sonuçlanan tahmin sayısı",
  correct: "Doğru tahmin sayısı",
  best_streak: "En uzun doğru tahmin serisi",
  official_wins: "Kazanılan resmi bahis",
  sp_profit: "Toplam net SP kazancı",
  underdog_wins: "Ters köşe (havuzun %20'sinden azıyla kazanılan)",
  duels_played: "Oynanan düello",
  duels_won: "Kazanılan düello",
  perfect_duels: "Bütün soruları doğru düello",
  social_created: "Açtığı sonuçlanmış sosyal bahis",
  fair_referee: "Kararı değiştirilmeden sonuçlanan hakemlik",
  login_streak: "En uzun giriş serisi (gün)",
  level: "Seviye",
  items_owned: "Sahip olunan market ürünü",
  quests_claimed: "Alınan görev ödülü",
};
