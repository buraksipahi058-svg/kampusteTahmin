"use server";

import { refresh } from "next/cache";
import type { ActionState } from "@/components/ui";
import { dbErrorMessage } from "@/lib/errors";
import { formatAmount } from "@/lib/format";
import { createClient } from "@/lib/supabase/server";

// admin_grant (yalnızca artı) / admin_adjust (iki yönlü): yalnızca süperadmin, gerekçe zorunlu,
// tek işlemde en fazla 1.000.000, kendine yapılamaz. Hepsi ledger'a kim yaptığıyla yazılır.
export async function changeBalance(_prev: ActionState, formData: FormData): Promise<ActionState> {
  const mode = String(formData.get("mode") ?? "grant");
  const currency = String(formData.get("currency") ?? "SSP") as "SP" | "SSP";
  const amount = Number(formData.get("amount"));
  const args = {
    p_user_id: String(formData.get("user_id") ?? ""),
    p_currency: currency,
    p_amount: amount,
    p_note: String(formData.get("note") ?? "").trim(),
  };
  if (!args.p_user_id) return { error: "Kullanıcı seç." };
  if (!Number.isInteger(amount) || amount === 0) return { error: "Tutar sıfırdan farklı bir tam sayı olmalı." };

  const supabase = await createClient();
  const { data, error } = await supabase.rpc(mode === "adjust" ? "admin_adjust" : "admin_grant", args);
  if (error) return { error: dbErrorMessage(error) };
  refresh();
  return { message: `İşlem yapıldı. Yeni ${currency} bakiyesi: ${formatAmount(data)}` };
}
