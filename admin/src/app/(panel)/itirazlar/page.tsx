import type { Metadata } from "next";
import { getStaff } from "@/lib/auth";
import { dbErrorMessage } from "@/lib/errors";
import { formatAmount, formatDateTime } from "@/lib/format";
import { createClient } from "@/lib/supabase/server";
import { DisputeForm } from "./dispute-form";

export const metadata: Metadata = { title: "İtirazlar · KampüsBet Yönetim" };

export default async function DisputesPage() {
  const staff = await getStaff();
  if (!staff) return null;
  const isModerator = staff.role === "superadmin" || staff.permissions.some((p) => p.key === "kullanici_bahsi_denetle");
  if (!isModerator) return <p className="text-sm">Bu sayfa kullanıcı bahsi denetleme izni olanlar içindir.</p>;

  const supabase = await createClient();
  // Açık itirazı olan, sonuç bekleyen sosyal bahisler. RLS: moderatör okulundaki (grup dahil) bahisleri görür.
  const { data: bets, error } = await supabase
    .from("bets")
    .select(
      "id, title, description, pool_total, proposed_option_id, result_submitted_at, dispute_until, school:clusters!cluster_id(name, type), referee:profiles!referee_id(first_name, last_name, referee_strikes), bet_options(id, label, position, pool_amount), bet_disputes!inner(id, reason, created_at, status, raiser:profiles!raised_by(first_name, last_name))",
    )
    .eq("type", "sp_social")
    .eq("status", "settling")
    .eq("bet_disputes.status", "open")
    .order("result_submitted_at", { ascending: true });

  return (
    <div className="flex flex-col gap-6">
      <div>
        <h1 className="text-2xl font-semibold">İtirazlar</h1>
        <p className="text-sm text-muted">
          Sosyal bahislerde hakemin sonucuna yapılan itirazlar. Karar verene kadar ödeme yapılmaz. Sonucu
          değiştirmek ya da iptal etmek hakeme ihtar yazar; ihtar sınırına ulaşan kişi sosyal bahis açamaz.
          Hakemi olduğun ya da yatırım yaptığın bahiste karar veremezsin.
        </p>
      </div>
      {error && <p className="text-sm text-danger">İtirazlar alınamadı: {dbErrorMessage(error)}</p>}
      {bets?.length === 0 && <p className="text-sm text-muted">Bekleyen itiraz yok.</p>}

      {bets?.map((bet) => {
        const options = [...bet.bet_options].sort((a, b) => a.position - b.position);
        const proposed = options.find((o) => o.id === bet.proposed_option_id);
        return (
          <section key={bet.id} className="rounded-xl border border-line bg-panel/90 p-4">
            <h2 className="text-lg font-medium">{bet.title}</h2>
            <p className="text-sm text-muted">
              {bet.school?.name}
              {bet.school?.type === "group" && " (özel grup)"} · Hakem: {bet.referee?.first_name}{" "}
              {bet.referee?.last_name} ({bet.referee?.referee_strikes ?? 0} ihtar) · Sonuç girildi:{" "}
              {bet.result_submitted_at && formatDateTime(bet.result_submitted_at)}
            </p>
            {bet.description && <p className="mt-1 text-sm">{bet.description}</p>}

            <ul className="mt-2 text-sm">
              {options.map((o) => (
                <li key={o.id} className={o.id === bet.proposed_option_id ? "font-semibold" : ""}>
                  {o.label}: {formatAmount(o.pool_amount)} SP{o.id === bet.proposed_option_id && " ← hakemin sonucu"}
                </li>
              ))}
            </ul>
            <p className="text-sm text-muted">Toplam havuz: {formatAmount(bet.pool_total)} SP</p>

            <h3 className="mt-3 text-sm font-medium">İtirazlar</h3>
            <ul className="text-sm">
              {bet.bet_disputes.map((d) => (
                <li key={d.id}>
                  {formatDateTime(d.created_at)} · {d.raiser?.first_name} {d.raiser?.last_name}: “{d.reason}”
                </li>
              ))}
            </ul>

            {proposed && (
              <DisputeForm
                betId={bet.id}
                proposedId={proposed.id}
                options={options.map((o) => ({ id: o.id, label: o.label }))}
              />
            )}
          </section>
        );
      })}
    </div>
  );
}
