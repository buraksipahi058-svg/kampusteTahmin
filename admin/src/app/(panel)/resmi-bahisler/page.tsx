import type { Metadata } from "next";
import Link from "next/link";
import { can, getStaff } from "@/lib/auth";
import { dbErrorMessage } from "@/lib/errors";
import { formatAmount, formatDateTime, formatOdds, isPast } from "@/lib/format";
import { createClient } from "@/lib/supabase/server";
import { BetActions } from "./bet-actions";
import { OddsForm } from "./odds-form";
import { buttonClass } from "@/components/kit";

export const metadata: Metadata = { title: "Resmi bahisler · KampüsBet Yönetim" };

const statusLabels = {
  open: "Açık",
  locked: "Kilitli",
  settling: "Sonuç bekliyor",
  settled: "Sonuçlandı",
  cancelled: "İptal edildi",
} as const;

export default async function OfficialBetsPage() {
  const staff = await getStaff();
  if (!staff) return null;

  const supabase = await createClient();
  // Görünürlük RLS'ten gelir: yetkili kendi okulunun, süperadmin tüm okulların bahislerini görür.
  const { data: bets, error } = await supabase
    .from("bets")
    .select(
      "id, title, description, status, cluster_id, locks_at, pool_total, max_stake, odds_mode, cancel_reason, school:clusters!cluster_id(name), bet_options(id, label, position, odds, pool_amount, is_winner)",
    )
    .eq("type", "ssp_official")
    .order("created_at", { ascending: false })
    .limit(50);

  const canCreate = staff.role === "superadmin" || staff.permissions.some((p) => p.key === "resmi_bahis_ac");

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-semibold">Resmi bahisler</h1>
          <p className="text-sm text-muted">
            SSP ile oynanır, sabit oranlıdır. Kazanan yatırımı × oran kadar SSP alır.
          </p>
        </div>
        {canCreate && (
          <Link
            href="/resmi-bahisler/yeni"
            className={buttonClass("primary")}
          >
            Yeni resmi bahis
          </Link>
        )}
      </div>

      {error && <p className="text-sm text-danger">Bahisler alınamadı: {dbErrorMessage(error)}</p>}
      {bets?.length === 0 && <p className="text-sm text-muted">Henüz resmi bahis yok.</p>}

      {bets?.map((bet) => {
        const options = [...bet.bet_options].sort((a, b) => a.position - b.position);
        const lockPassed = isPast(bet.locks_at);
        const active = bet.status === "open" || bet.status === "locked";
        const canClose = active && can(staff, bet.cluster_id, "resmi_bahis_kapat");
        return (
          <section key={bet.id} className="rounded-xl border border-line bg-panel/90 p-4">
            <div className="flex flex-wrap items-baseline justify-between gap-2">
              <h2 className="text-lg font-medium">{bet.title}</h2>
              <span className="text-sm text-muted">
                {statusLabels[bet.status]}
                {bet.status === "open" && lockPassed && " · kapanış zamanı geçti"}
              </span>
            </div>
            <p className="text-sm text-muted">
              {bet.school?.name} · Kapanış: {formatDateTime(bet.locks_at)}
              {bet.max_stake != null && ` · Kişi başı en fazla ${formatAmount(bet.max_stake)} SSP`}
              {bet.odds_mode === "pool" && " · havuz sistemi"}
            </p>
            {bet.description && <p className="mt-1 text-sm">{bet.description}</p>}
            {bet.cancel_reason && <p className="mt-1 text-sm text-danger">İptal gerekçesi: {bet.cancel_reason}</p>}

            <table className="mt-3 w-full text-sm">
              <thead className="text-left text-muted">
                <tr>
                  <th className="font-normal">Seçenek</th>
                  <th className="font-normal">Oran</th>
                  <th className="font-normal">Yatırılan</th>
                  <th className="font-normal">Kazanırsa ödenecek (yaklaşık)</th>
                </tr>
              </thead>
              <tbody>
                {options.map((o) => (
                  <tr key={o.id} className={o.is_winner ? "font-semibold text-success" : ""}>
                    <td>
                      {o.label}
                      {o.is_winner && " ✓ kazandı"}
                    </td>
                    <td>{formatOdds(o.odds)}</td>
                    <td>{formatAmount(o.pool_amount)} SSP</td>
                    <td>{o.odds == null ? "–" : `${formatAmount(Math.floor(o.pool_amount * o.odds))} SSP`}</td>
                  </tr>
                ))}
              </tbody>
            </table>
            <p className="mt-1 text-sm text-muted">Toplam yatırılan: {formatAmount(bet.pool_total)} SSP</p>

            {bet.status === "open" && !lockPassed && bet.odds_mode === "fixed" && can(staff, bet.cluster_id, "resmi_bahis_ac") && (
              <OddsForm betId={bet.id} options={options.map((o) => ({ id: o.id, label: o.label, odds: o.odds }))} />
            )}
            {canClose && (
              <BetActions
                betId={bet.id}
                options={options.map((o) => ({ id: o.id, label: o.label }))}
                canLock={bet.status === "open" && !lockPassed}
                canSettle={bet.status === "locked" || lockPassed}
              />
            )}
          </section>
        );
      })}
    </div>
  );
}
