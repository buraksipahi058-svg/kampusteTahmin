"use server";

import { redirect } from "next/navigation";
import type { ActionState } from "@/components/ui";
import { createClient } from "@/lib/supabase/server";

export async function login(_prev: ActionState, formData: FormData): Promise<ActionState> {
  const email = String(formData.get("email") ?? "").trim();
  const password = String(formData.get("password") ?? "");
  if (!email || !password) return { error: "E-posta ve şifre gerekli." };

  const supabase = await createClient();
  const { error } = await supabase.auth.signInWithPassword({ email, password });
  if (error) {
    return {
      error:
        error.code === "invalid_credentials"
          ? "E-posta ya da şifre hatalı."
          : error.code === "email_not_confirmed"
            ? "E-posta adresi henüz onaylanmamış."
            : "Giriş yapılamadı. Biraz sonra tekrar dene.",
    };
  }
  redirect("/");
}

export async function logout() {
  const supabase = await createClient();
  await supabase.auth.signOut();
  redirect("/giris");
}
