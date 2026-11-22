// Sunucu tarafı Supabase istekleri için fetch sarmalayıcısı.
//
// 1) Üst süre: bir servis yanıt vermezse sayfa, API geçidinin kendi zaman aşımına (dakikalar)
//    kadar asılı kalmaz; hata ekranı gösterilir. AbortSignal.timeout() yerine AbortController
//    kullanılır: iptal "AbortError" olarak döner ve postgrest-js bu hatayı yeniden denemez
//    (TimeoutError'ı dener, toplam süre katlanırdı).
// 2) PGRST303 "JWT issued at future": PostgREST saati saniyelik önbellekten okur; girişle aynı
//    saniyede gelen istekte yeni jeton "gelecekte üretilmiş" sayılabilir. Yalnızca bu hata için
//    bir saniye sonra bir kez yeniden denenir.
const SERVER_REQUEST_TIMEOUT_MS = 10_000;
const ISSUED_AT_FUTURE_RETRY_DELAY_MS = 1_100;

async function fetchOnce(input: RequestInfo | URL, init: RequestInit | undefined): Promise<Response> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), SERVER_REQUEST_TIMEOUT_MS);
  const signal = init?.signal ? AbortSignal.any([init.signal, controller.signal]) : controller.signal;
  try {
    return await fetch(input, { ...init, signal });
  } finally {
    clearTimeout(timer);
  }
}

async function isIssuedAtFuture(response: Response): Promise<boolean> {
  if (response.status !== 401) return false;
  try {
    const body: unknown = await response.clone().json();
    // PGRST303 başka jeton hataları (ör. süresi dolmuş) için de kullanılır; yalnızca "issued at future".
    return (
      typeof body === "object" &&
      body !== null &&
      "code" in body &&
      body.code === "PGRST303" &&
      "message" in body &&
      typeof body.message === "string" &&
      body.message.includes("future")
    );
  } catch {
    return false;
  }
}

export const fetchWithTimeout: typeof fetch = async (input, init) => {
  const response = await fetchOnce(input, init);
  if (!(await isIssuedAtFuture(response))) return response;

  await new Promise((resolve) => setTimeout(resolve, ISSUED_AT_FUTURE_RETRY_DELAY_MS));
  return fetchOnce(input, init);
};
