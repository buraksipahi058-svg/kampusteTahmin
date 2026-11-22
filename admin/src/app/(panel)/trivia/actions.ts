"use server";

import { refresh } from "next/cache";
import type { ActionState } from "@/components/ui";
import { dbErrorMessage } from "@/lib/errors";
import { createClient } from "@/lib/supabase/server";

// save_trivia_question: okula özel soru trivia_yonet, genel soru (okul boş) süperadmin ister.

export async function saveQuestion(_prev: ActionState, formData: FormData): Promise<ActionState> {
  const options = formData.getAll("option").map((v) => String(v).trim());
  const correct = Number(formData.get("correct"));
  const schoolId = String(formData.get("school_id") ?? "");
  if (options.some((o) => !o)) return { error: "Şıklar boş olamaz." };
  if (!Number.isInteger(correct) || correct < 0 || correct >= options.length) return { error: "Doğru şıkkı seç." };

  const supabase = await createClient();
  const { error } = await supabase.rpc("save_trivia_question", {
    // Genel soru için okul boş gönderilir (yalnızca süperadmin).
    p_id: null as unknown as string,
    p_school_id: (schoolId || null) as unknown as string,
    p_question: String(formData.get("question") ?? "").trim(),
    p_options: options,
    p_correct_index: correct,
    p_category: String(formData.get("category") ?? "").trim(),
  });
  if (error) return { error: dbErrorMessage(error) };
  refresh();
  return { message: "Soru eklendi." };
}

export async function toggleQuestion(_prev: ActionState, formData: FormData): Promise<ActionState> {
  const supabase = await createClient();
  const id = String(formData.get("id") ?? "");
  const { data: q, error: readError } = await supabase
    .from("trivia_questions")
    .select("school_id, question, options, correct_index, category, active")
    .eq("id", id)
    .maybeSingle();
  if (readError || !q) return { error: "Soru bulunamadı." };

  const { error } = await supabase.rpc("save_trivia_question", {
    p_id: id,
    p_school_id: q.school_id as string,
    p_question: q.question,
    p_options: q.options,
    p_correct_index: q.correct_index,
    p_category: q.category ?? "",
    p_active: !q.active,
  });
  if (error) return { error: dbErrorMessage(error) };
  refresh();
  return { message: q.active ? "Soru kapatıldı." : "Soru açıldı." };
}
