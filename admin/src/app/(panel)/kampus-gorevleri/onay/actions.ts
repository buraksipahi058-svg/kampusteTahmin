"use server";

import { refresh } from "next/cache";
import type { ActionState } from "@/components/ui";
import { dbErrorMessage } from "@/lib/errors";
import { createClient } from "@/lib/supabase/server";

// review_campus_submission: okulunda kampus_gorevi_yonet ya da süperadmin; ret gerekçesi zorunlu (veritabanı denetler).
export async function reviewSubmission(_prev: ActionState, formData: FormData): Promise<ActionState> {
  const approve = formData.get("decision") === "approve";
  const note = String(formData.get("note") ?? "").trim();
  if (!approve && note.length < 3) return { error: "Reddederken gerekçe yaz (en az 3 karakter)." };
  const supabase = await createClient();
  const { error } = await supabase.rpc("review_campus_submission", {
    p_submission_id: String(formData.get("id") ?? ""),
    p_approve: approve,
    p_note: note,
  });
  if (error) return { error: dbErrorMessage(error) };
  refresh();
  return { message: approve ? "Onaylandı; ödül öğrencinin hesabına geçti." : "Reddedildi; öğrenci bildirimde görür." };
}
