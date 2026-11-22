import type { Database } from "@/lib/supabase/database.types";

export type MarketCategory = Database["public"]["Enums"]["market_category"];
export type Currency = Database["public"]["Enums"]["currency"];

export type MarketItem = {
  id: string;
  school_id: string | null;
  name: string;
  description: string | null;
  category: MarketCategory;
  icon: string | null;
  color: string | null;
  price: number;
  currency: Currency;
  available_from: string | null;
  available_until: string | null;
  active: boolean;
};

export const categoryLabels: Record<MarketCategory, string> = {
  title: "Unvan",
  badge: "Rozet",
  frame: "Profil çerçevesi",
  name_color: "İsim rengi",
};

// Unvan ve rozet simgeyle (emoji), çerçeve ve isim rengi renkle görünür.
export const usesColor = (category: MarketCategory) => category === "frame" || category === "name_color";
