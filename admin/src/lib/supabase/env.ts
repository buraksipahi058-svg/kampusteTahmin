// NEXT_PUBLIC_ değişkenleri build sırasında gömülebilsin diye birebir yazılarak okunur.
export function getSupabasePublicEnv() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const publishableKey = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;

  if (!url || !publishableKey) {
    throw new Error(
      "NEXT_PUBLIC_SUPABASE_URL ve NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY tanımlı olmalı (.env.example dosyasına bak).",
    );
  }

  return { url, publishableKey };
}
