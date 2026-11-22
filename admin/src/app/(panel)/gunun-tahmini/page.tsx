import type { Metadata } from "next";
import { can, getStaff } from "@/lib/auth";
import { dbErrorMessage } from "@/lib/errors";
import { formatAmount, formatDateTime, isPast } from "@/lib/format";
import { createClient } from "@/lib/supabase/server";
import { PredictionActions } from "./prediction-actions";
import { PredictionForm } from "./prediction-form";

export const metadata: Metadata = { title: "Günün tahmini · KampüsBet Yönetim" };

const statusLabels = {
  open: "Açık",
  locked: "Kilitli",
  settling: "Sonuç bekliyor",
  settled: "Sonuçlandı",
  cancelled: "İptal edildi",
} as const;

export default async function DailyPredictionsPage() {
  const staff = await getStaff();
  if (!staff) return null;

  const supabase = await createClient();
  // Günün tahmini = sonucu admin giren mini oyun. Görünürlük RLS'ten gelir.
  const { data: predictions, error } = await supabase
    .from("bets")
    .select(
      "id, title, description, status, cluster_id, locks_at, pool_total, max_stake, cancel_reason, school:clusters!cluster_id(name), bet_options(id, label, position, pool_amount, is_winner)",
    )
    .eq("type", "sp_minigame")
    .eq("settlement_mode", "admin")
    .order("locks_at", { ascending: false })
    .limit(50);

  // Süperadmin her okulda, yetkili resmi_bahis_ac izni olduğu okullarda açabilir.
  const openSchoolIds = staff.permissions.filter((p) => p.key === "resmi_bahis_ac").map((p) => p.schoolId);
  const { data: schools } = await supabase.from("clusters").select("id, name").eq("type", "school").order("name");
  const allowed = (schools ?? []).filter((s) => staff.role === "superadmin" || openSchoolIds.includes(s.id));

  return (
    <div className="flex flex-col gap-6">
      <div>
        <h1 className="text-2xl font-semibold">Günün tahmini</h1>
        <p className="text-sm text-zinc-500">
          Evet / hayır sorusu, SP ile havuz sistemi: kazananlar tüm havuzu yatırdıkları oranda paylaşır. Kazanan
          tarafa kimse yatırmadıysa herkese iade. Kapanıştan sonra 3 gün içinde sonuç girilmezse kendiliğinden iptal
          edilir. Soruyu açan ve sonuç girebilen yatırım yapamaz.
        </p>
      </div>

      {allowed.length > 0 && <PredictionForm schools={allowed} />}

      {error && <p className="text-sm text-red-700">Tahminler alınamadı: {dbErrorMessage(error)}</p>}
      {predictions?.length === 0 && <p className="text-sm text-zinc-500">Henüz günün tahmini yok.</p>}

      {predictions?.map((p) => {
        const options = [...p.bet_options].sort((a, b) => a.position - b.position);
        const lockPassed = isPast(p.locks_at);
        const active = p.status === "open" || p.status === "locked";
        const canClose = active && can(staff, p.cluster_id, "resmi_bahis_kapat");
        return (
          <section key={p.id} className="rounded-lg border border-zinc-200 p-4 dark:border-zinc-800">
            <div className="flex flex-wrap items-baseline justify-between gap-2">
              <h2 className="text-lg font-medium">{p.title}</h2>
              <span className="text-sm text-zinc-500">
                {statusLabels[p.status]}
                {p.status === "open" && lockPassed && " · kapandı, sonuç bekliyor"}
              </span>
            </div>
            <p className="text-sm text-zinc-500">
              {p.school?.name} · Kapanış: {formatDateTime(p.locks_at)}
              {p.max_stake != null && ` · Kişi başı en fazla ${formatAmount(p.max_stake)} SP`}
            </p>
            {p.description && <p className="mt-1 text-sm">{p.description}</p>}
            {p.cancel_reason && <p className="mt-1 text-sm text-red-700">İptal gerekçesi: {p.cancel_reason}</p>}

            <ul className="mt-3 flex flex-wrap gap-4 text-sm">
              {options.map((o) => (
                <li key={o.id} className={o.is_winner ? "font-semibold text-green-700 dark:text-green-400" : ""}>
                  {o.label}: {formatAmount(o.pool_amount)} SP
                  {o.is_winner && " ✓ sonuç"}
                </li>
              ))}
              <li className="text-zinc-500">Toplam havuz: {formatAmount(p.pool_total)} SP</li>
            </ul>

            {canClose && (
              <PredictionActions
                betId={p.id}
                options={options.map((o) => ({ id: o.id, label: o.label }))}
                canSettle={lockPassed || p.status === "locked"}
              />
            )}
          </section>
        );
      })}
    </div>
  );
}
