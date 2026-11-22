"use server";

import { refresh } from "next/cache";
import { redirect } from "next/navigation";
import type { ActionState } from "@/components/ui";
import { dbErrorMessage } from "@/lib/errors";
import { istanbulLocalToIso } from "@/lib/format";
import { createClient } from "@/lib/supabase/server";
import { usesColor, type Currency, type MarketCategory } from "./labels";

const text = (formData: FormData, key: string) => String(formData.get(key) ?? "").trim();
// Üretilen RPC tipleri null kabul etmiyor görünür; veritabanı null'u (genel ürün, tarihsiz, renksiz) bekler.
const nullable = (value: string) => (value || null) as unknown as string;

// save_market_item: okul ürünü market_yonet, genel ürün yalnızca süperadmin; tür sonradan değişmez.

export async function saveItem(_prev: ActionState, formData: FormData): Promise<ActionState> {
  const id = text(formData, "id");
  const category = text(formData, "category") as MarketCategory;
  const price = Number(text(formData, "price"));
  const minLevel = Number(text(formData, "min_level") || "1");
  const from = text(formData, "available_from");
  const until = text(formData, "available_until");
  if (!Number.isInteger(price) || price < 1) return { error: "Fiyat en az 1 olmalı." };
  if (!Number.isInteger(minLevel) || minLevel < 1 || minLevel > 100) return { error: "Seviye 1 ile 100 arasında olmalı." };

  const supabase = await createClient();
  const { error } = await supabase.rpc("save_market_item", {
    p_id: nullable(id),
    p_school_id: nullable(text(formData, "school_id")),
    p_name: text(formData, "name"),
    p_description: text(formData, "description"),
    p_category: category,
    p_price: price,
    p_currency: text(formData, "currency") as Currency,
    p_icon: nullable(usesColor(category) ? "" : text(formData, "icon")),
    p_color: nullable(usesColor(category) ? text(formData, "color") : ""),
    p_available_from: nullable(from && istanbulLocalToIso(from)),
    p_available_until: nullable(until && istanbulLocalToIso(until)),
    p_active: id ? formData.get("active") === "on" : true,
    p_min_level: minLevel,
  });
  if (error) return { error: dbErrorMessage(error) };
  if (id) redirect("/market");
  refresh();
  return { message: "Ürün eklendi; öğrenciler uygulamada Market sekmesinde görür." };
}

export async function toggleItem(_prev: ActionState, formData: FormData): Promise<ActionState> {
  const supabase = await createClient();
  const id = text(formData, "id");
  const { data: item, error: readError } = await supabase
    .from("market_items")
    .select("school_id, name, description, category, icon, color, price, currency, available_from, available_until, active, min_level")
    .eq("id", id)
    .maybeSingle();
  if (readError || !item) return { error: "Ürün bulunamadı." };

  const { error } = await supabase.rpc("save_market_item", {
    p_id: id,
    p_school_id: item.school_id as string,
    p_name: item.name,
    p_description: item.description ?? "",
    p_category: item.category,
    p_price: item.price,
    p_currency: item.currency,
    p_icon: item.icon as string,
    p_color: item.color as string,
    p_available_from: item.available_from as string,
    p_available_until: item.available_until as string,
    p_active: !item.active,
    p_min_level: item.min_level,
  });
  if (error) return { error: dbErrorMessage(error) };
  refresh();
  return { message: item.active ? "Ürün satıştan kaldırıldı." : "Ürün satışa açıldı." };
}
