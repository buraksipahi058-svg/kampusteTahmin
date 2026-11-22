import { NextResponse, type NextRequest } from "next/server";
import { createServerClient } from "@supabase/ssr";
import type { User } from "@supabase/supabase-js";
import { getSupabasePublicEnv } from "./env";
import { fetchWithTimeout } from "./fetch-with-timeout";

// Her istekte oturumu doğrular, gerekirse jetonu yeniler ve güncel çerezleri hem isteğe hem yanıta yazar.
export async function updateSession(request: NextRequest): Promise<{ response: NextResponse; user: User | null }> {
  const { url, publishableKey } = getSupabasePublicEnv();
  let response = NextResponse.next({ request });

  const supabase = createServerClient(url, publishableKey, {
    global: { fetch: fetchWithTimeout },
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(cookiesToSet, headers) {
        cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value));
        response = NextResponse.next({ request });
        cookiesToSet.forEach(({ name, value, options }) => response.cookies.set(name, value, options));
        Object.entries(headers).forEach(([key, value]) => response.headers.set(key, value));
      },
    },
  });

  // createServerClient ile getUser arasına kod ekleme: oturum yenilemesi burada olur.
  // getUser jetonu Auth sunucusunda doğrular (çerezdeki veriye körü körüne güvenmez).
  const {
    data: { user },
  } = await supabase.auth.getUser();

  return { response, user };
}
