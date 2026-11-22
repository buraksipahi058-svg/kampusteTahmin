import "server-only";
import { cookies } from "next/headers";
import { createServerClient } from "@supabase/ssr";
import type { Database } from "./database.types";
import { getSupabasePublicEnv } from "./env";
import { fetchWithTimeout } from "./fetch-with-timeout";

// Server Component ve Server Action'lar için Supabase istemcisi. Oturum çerezden okunur ve
// kullanıcının kendi yetkisiyle çalışır (RLS ve fonksiyonlardaki yetki kontrolleri geçerli).
// Secret key kullanılmaz.
export async function createClient() {
  const { url, publishableKey } = getSupabasePublicEnv();
  const cookieStore = await cookies();

  return createServerClient<Database>(url, publishableKey, {
    global: { fetch: fetchWithTimeout },
    cookies: {
      getAll() {
        return cookieStore.getAll();
      },
      setAll(cookiesToSet) {
        try {
          cookiesToSet.forEach(({ name, value, options }) => cookieStore.set(name, value, options));
        } catch {
          // Server Component'ten çağrıldığında çerez yazılamaz; oturum yenilemesini proxy üstlenir.
        }
      },
    },
  });
}
