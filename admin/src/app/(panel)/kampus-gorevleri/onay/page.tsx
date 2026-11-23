import type { Metadata } from "next";
import Link from "next/link";
import { getStaff } from "@/lib/auth";
import { dbErrorMessage } from "@/lib/errors";
import { formatAmount, formatDateTime } from "@/lib/format";
import { createClient } from "@/lib/supabase/server";
import { ReviewForm } from "./review-form";

export const metadata: Metadata = { title: "Kampüs görevi onayı · KampüsBet Yönetim" };

// Fotoğraflı kampüs görevlerinin onay kuyruğu. Fotoğraflar kişiye özel depolamada; burada 5 dakikalık imzalı
// bağlantıyla gösterilir (RLS: okulunda kampus_gorevi_yonet ya da süperadmin). 7 günde karara bağlanmayan düşer.
export default async function CampusReviewPage() {
  const staff = await getStaff();
  if (!staff) return null;
  const managed = staff.permissions.some((p) => p.key === "kampus_gorevi_yonet");
  if (staff.role !== "superadmin" && !managed) {
    return <p className="text-sm">Bu sayfa kampüs görevi yönetme izni olanlar içindir.</p>;
  }

  const supabase = await createClient();
  const { data: pending, error } = await supabase
    .from("campus_task_submissions")
    .select("id, created_at, photo_path, reward_amount, reward_currency, reward_xp, task:campus_tasks!task_id(title, icon, quota), student:profiles!user_id(first_name, last_name, department)")
    .eq("status", "pending")
    .order("created_at", { ascending: true })
    .limit(50);

  const paths = (pending ?? []).map((s) => s.photo_path).filter((p): p is string => !!p);
  const { data: signed } = paths.length
    ? await supabase.storage.from("campus-proofs").createSignedUrls(paths, 300)
    : { data: [] };
  const urlOf = new Map((signed ?? []).map((s) => [s.path, s.signedUrl]));

  return (
    <div className="flex flex-col gap-6">
      <Link href="/kampus-gorevleri" className="text-sm underline">
        ← Kampüs görevleri
      </Link>
      <div>
        <h1 className="text-2xl font-semibold">Onay bekleyen fotoğraflar ({pending?.length ?? 0})</h1>
        <p className="text-sm text-muted">
          Onaylayınca ödül hemen öğrencinin hesabına geçer. Reddederken gerekçe yaz; öğrenci bildirimde görür ve
          yeniden deneyebilir. Fotoğraflar karardan 30 gün sonra silinir. Fotoğrafta başka kişilerin yüzü varsa reddet.
        </p>
      </div>
      {error && <p className="text-sm text-danger">Gönderiler alınamadı: {dbErrorMessage(error)}</p>}
      {pending?.length === 0 && <p className="text-sm text-muted">Onay bekleyen gönderi yok.</p>}
      <ul className="grid gap-4 sm:grid-cols-2">
        {pending?.map((s) => {
          const url = s.photo_path ? urlOf.get(s.photo_path) : undefined;
          return (
            <li key={s.id} className="flex flex-col gap-2 rounded-xl border border-line bg-panel/90 p-3">
              <p className="font-medium">
                {s.task?.icon} {s.task?.title}
              </p>
              <p className="text-sm text-muted">
                {s.student?.first_name} {s.student?.last_name}
                {s.student?.department && ` · ${s.student.department}`} · {formatDateTime(s.created_at)} ·{" "}
                {formatAmount(s.reward_amount)} {s.reward_currency}
                {s.reward_xp > 0 && ` · ${s.reward_xp} XP`}
              </p>
              {url ? (
                // eslint-disable-next-line @next/next/no-img-element -- süreli imzalı bağlantı; Next görsel iyileştirmesi kullanılmaz
                <img src={url} alt="Gönderilen kanıt fotoğrafı" className="max-h-96 w-full rounded object-contain" />
              ) : (
                <p className="text-sm text-danger">Fotoğraf açılamadı.</p>
              )}
              {s.reward_currency === "SSP" && staff.role !== "superadmin" ? (
                <p className="text-sm text-muted">SSP ödüllü gönderiye yalnızca süperadmin karar verir.</p>
              ) : (
                <ReviewForm id={s.id} />
              )}
            </li>
          );
        })}
      </ul>
    </div>
  );
}
