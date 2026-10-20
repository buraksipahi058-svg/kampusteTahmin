import { Suspense } from "react";
import { connection } from "next/server";

type Status =
  | { ok: true }
  | { ok: false; reason: string };

// Adım 0 bağlantı kontrolü: Supabase Auth'un sağlık uç noktasına publishable key ile istek atar.
async function checkSupabase(): Promise<Status> {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  if (!url || !key) {
    return { ok: false, reason: "admin/.env.local içinde Supabase URL veya publishable key yok." };
  }

  try {
    const res = await fetch(`${url}/auth/v1/health`, {
      headers: { apikey: key },
      cache: "no-store",
    });
    if (!res.ok) {
      return { ok: false, reason: `Supabase ${res.status} döndürdü.` };
    }
    return { ok: true };
  } catch {
    return { ok: false, reason: "Supabase'e ulaşılamadı." };
  }
}

async function SupabaseStatus() {
  await connection();
  const status = await checkSupabase();

  return status.ok ? (
    <p className="mt-2 text-green-700 dark:text-green-400">Bağlı</p>
  ) : (
    <p className="mt-2 text-red-700 dark:text-red-400">Bağlı değil: {status.reason}</p>
  );
}

export default function Home() {
  return (
    <main className="mx-auto flex w-full max-w-xl flex-1 flex-col gap-6 px-4 py-16">
      <h1 className="text-2xl font-semibold">KampüsBet Yönetim</h1>
      <section className="rounded-lg border border-zinc-200 p-4 dark:border-zinc-800">
        <h2 className="font-medium">Supabase bağlantısı</h2>
        <Suspense fallback={<p className="mt-2 text-zinc-500">Kontrol ediliyor…</p>}>
          <SupabaseStatus />
        </Suspense>
      </section>
    </main>
  );
}
