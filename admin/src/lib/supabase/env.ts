// NEXT_PUBLIC_ değişkenleri build sırasında gömülebilsin diye birebir yazılarak okunur.
export function getSupabasePublicEnv() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const publishableKey = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;

  if (!url || !publishableKey) {
    throw new Error(
      "NEXT_PUBLIC_SUPABASE_URL ve NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY tanımlı olmalı (.env.example dosyasına bak).",
    );
  }

  // NEXT_PUBLIC_ değerleri tarayıcıya gider: secret / service_role anahtarı (yeni ya da eski tip) asla burada olmamalı.
  if (!publishableKey.startsWith("sb_publishable_")) {
    throw new Error("NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY yalnızca publishable key (sb_publishable_...) olabilir.");
  }

  return { url, publishableKey };
}
