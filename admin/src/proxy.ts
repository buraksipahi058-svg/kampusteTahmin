import { NextResponse, type NextRequest } from "next/server";
import { updateSession } from "@/lib/supabase/proxy";

const LOGIN_PATH = "/giris";

// Yönlendirme yanıtına yenilenmiş oturum çerezlerini de taşır.
function redirectWithSession(url: URL, sessionResponse: NextResponse) {
  const redirect = NextResponse.redirect(url);
  sessionResponse.cookies.getAll().forEach((cookie) => redirect.cookies.set(cookie));
  return redirect;
}

// Giriş sayfası dışındaki her yer oturum ister. Rol kontrolü (yetkili / süperadmin) panel
// düzeninde yapılır; asıl yetki kontrolü her işlemde veritabanındadır.
export async function proxy(request: NextRequest) {
  const { response, user } = await updateSession(request);
  const { pathname } = request.nextUrl;

  if (!user && pathname !== LOGIN_PATH) {
    return redirectWithSession(new URL(LOGIN_PATH, request.url), response);
  }
  if (user && pathname === LOGIN_PATH) {
    return redirectWithSession(new URL("/", request.url), response);
  }
  return response;
}

export const config = {
  // Next'in kendi yolları (/_next/static, /_next/image, geliştirmede /_next/hmr canlı yenileme bağlantısı)
  // ve statik dosyalar oturum kontrolünden geçmez.
  matcher: ["/((?!_next/|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp|ico)$).*)"],
};
