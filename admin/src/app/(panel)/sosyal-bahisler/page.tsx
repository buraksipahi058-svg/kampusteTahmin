import type { Metadata } from "next";
import { getStaff } from "@/lib/auth";
import { dbErrorMessage } from "@/lib/errors";
import { formatAmount, formatDateTime, isPast } from "@/lib/format";
import { createClient } from "@/lib/supabase/server";
import { CancelSocialBet } from "./cancel-form";

export const metadata: Metadata = { title: "Sosyal bahisler · KampüsBet Yönetim" };

// Sonucu girilmemiş sosyal bahisler (moderatör). Kapanışı geçmiş ve hakemin sonuç girmediği bahisler üstte;
// süre dolunca zamanlanmış iş zaten iptal edip hakeme ihtar yazar, moderatör daha önce de iptal edebilir.
// Uygunsuz soruları açıkken kaldırmak için de kullanılır. İtiraz bekleyenler "İtirazlar" sayfasındadır.
export default async function SocialBetsPage() {
  const staff = await getStaff();
  if (!staff) return null;
  const isModerator = staff.role === "superadmin" || staff.permissions.some((p) => p.key === "kullanici_bahsi_denetle");
  if (!isModerator) return <p className="text-sm">Bu sayfa kullanıcı bahsi denetleme izni olanlar içindir.</p>;

  const supabase = await createClient();
  const { data: bets, error } = await supabase
    .from("bets")
    .select(
      "id, title, status, locks_at, pool_total, created_at, school:clusters!cluster_id(name), referee:profiles!referee_id(first_name, last_name, referee_strikes)",
    )
    .eq("type", "sp_social")
    .in("status", ["open", "locked"])
    .order("locks_at", { ascending: true })
    .limit(200);

  const overdue = (bets ?? []).filter((b) => isPast(b.locks_at));
  const open = (bets ?? []).filter((b) => !isPast(b.locks_at));

  const list = (items: typeof overdue, empty: string) =>
    items.length === 0 ? (
      <p className="text-sm text-muted">{empty}</p>
    ) : (
      <ul className="flex flex-col divide-y divide-line">
        {items.map((b) => (
          <li key={b.id} className="flex flex-wrap items-start justify-between gap-3 py-3 text-sm">
            <div>
              <p className="font-medium">{b.title}</p>
              <p className="text-muted">
                {b.school?.name} · hakem {b.referee?.first_name} {b.referee?.last_name} (ihtar {b.referee?.referee_strikes ?? 0}) ·
                havuz {formatAmount(b.pool_total)} SP · kapanış {formatDateTime(b.locks_at)}
              </p>
            </div>
            <CancelSocialBet betId={b.id} />
          </li>
        ))}
      </ul>
    );

  return (
    <div className="flex flex-col gap-6">
      <div>
        <h1 className="text-2xl font-semibold">Sosyal bahisler</h1>
        <p className="text-sm text-muted">
          Sonucu girilmemiş sosyal bahisler. Hakem kapanıştan sonra süresi içinde sonuç girmezse bahis kendiliğinden
          iptal edilir ve hakeme ihtar yazılır. İptal herkese iade eder ve geri alınamaz.
        </p>
      </div>
      {error && <p className="text-sm text-danger">Bahisler alınamadı: {dbErrorMessage(error)}</p>}
      <section className="flex flex-col gap-2">
        <h2 className="text-lg font-medium">Kapanışı geçmiş, sonuç bekleyen ({overdue.length})</h2>
        {list(overdue, "Sonuç bekleyen bahis yok.")}
      </section>
      <section className="flex flex-col gap-2">
        <h2 className="text-lg font-medium">Açık ({open.length})</h2>
        {list(open, "Açık sosyal bahis yok.")}
      </section>
    </div>
  );
}
