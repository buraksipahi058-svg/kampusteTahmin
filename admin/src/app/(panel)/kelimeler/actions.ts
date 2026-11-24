"use server";

import { refresh } from "next/cache";
import type { ActionState } from "@/components/ui";
import { dbErrorMessage } from "@/lib/errors";
import { createClient } from "@/lib/supabase/server";

// save_word_puzzle: okula kelime kelime_yonet, bütün okullara (okul boş) süperadmin ister. Kelime sunucuda
// Türkçe büyük harfe çevrilir (i → İ); 4–8 harf, geçmiş güne girilmez, oynanmaya başlanan değişmez.

export async function saveWord(_prev: ActionState, formData: FormData): Promise<ActionState> {
  const word = String(formData.get("word") ?? "").trim();
  const date = String(formData.get("date") ?? "");
  const schoolId = String(formData.get("school_id") ?? "");
  if (!word || !date) return { error: "Gün ve kelime girilmeli." };

  const supabase = await createClient();
  const { error } = await supabase.rpc("save_word_puzzle", {
    p_id: null as unknown as string,
    // Bütün okullar için okul boş gönderilir (yalnızca süperadmin).
    p_school_id: (schoolId || null) as unknown as string,
    p_puzzle_date: date,
    p_word: word,
  });
  if (error) return { error: dbErrorMessage(error) };
  refresh();
  return { message: "Kelime kaydedildi." };
}

export async function deleteWord(_prev: ActionState, formData: FormData): Promise<ActionState> {
  const supabase = await createClient();
  const { error } = await supabase.rpc("delete_word_puzzle", { p_id: String(formData.get("id") ?? "") });
  if (error) return { error: dbErrorMessage(error) };
  refresh();
  return { message: "Kelime silindi." };
}
