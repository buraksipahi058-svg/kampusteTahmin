"use server";

import { refresh } from "next/cache";
import type { ActionState } from "@/components/ui";
import type { PermissionKey } from "@/lib/auth";
import { dbErrorMessage } from "@/lib/errors";
import { createClient } from "@/lib/supabase/server";

// grant_permission / revoke_permission yalnızca süperadmine izin verir ve denetim kaydına yazar.

function args(formData: FormData) {
  return {
    p_user_id: String(formData.get("user_id") ?? ""),
    p_school_id: String(formData.get("school_id") ?? ""),
    p_key: String(formData.get("key") ?? "") as PermissionKey,
  };
}

export async function grantPermission(_prev: ActionState, formData: FormData): Promise<ActionState> {
  const supabase = await createClient();
  const { error } = await supabase.rpc("grant_permission", args(formData));
  if (error) return { error: dbErrorMessage(error) };
  refresh();
  return { message: "İzin verildi." };
}

export async function revokePermission(_prev: ActionState, formData: FormData): Promise<ActionState> {
  const supabase = await createClient();
  const { error } = await supabase.rpc("revoke_permission", args(formData));
  if (error) return { error: dbErrorMessage(error) };
  refresh();
  return { message: "İzin geri alındı." };
}
