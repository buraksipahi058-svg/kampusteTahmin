import type { Metadata } from "next";
import Link from "next/link";
import { getStaff } from "@/lib/auth";
import { dbErrorMessage } from "@/lib/errors";
import { formatAmount, formatDateTime } from "@/lib/format";
import type { Database } from "@/lib/supabase/database.types";
import { createClient } from "@/lib/supabase/server";

export const metadata: Metadata = { title: "İstatistik · KampüsBet Yönetim" };

type Metric = Database["public"]["Enums"]["leaderboard_metric"];

const metrics: { key: Metric; label: string }[] = [
  { key: "hit_rate", label: "İsabet oranı" },
  { key: "sp_profit", label: "En çok kazanan (SP)" },
  { key: "best_streak", label: "En iyi seri" },
  { key: "ssp_profit", label: "SSP kazancı" },
];

const periods = [
  { key: "bu-hafta", label: "Bu hafta", period: "week", weeksAgo: 0 },
  { key: "gecen-hafta", label: "Geçen hafta", period: "week", weeksAgo: 1 },
  { key: "tum-zamanlar", label: "Tüm zamanlar", period: "all_time", weeksAgo: 0 },
] as const;

function formatValue(metric: Metric, value: number, sample: number) {
  switch (metric) {
    case "hit_rate":
      return `%${(value * 100).toLocaleString("tr-TR", { maximumFractionDigits: 1 })} (${Math.round(value * sample)}/${sample})`;
    case "sp_profit":
      return `+${formatAmount(value)} SP`;
    case "ssp_profit":
      return `+${formatAmount(value)} SSP`;
    case "best_streak":
      return `${value} doğru üst üste`;
  }
}

const one = (v: string | string[] | undefined) => (Array.isArray(v) ? v[0] : v);

export default async function StatsPage({ searchParams }: PageProps<"/istatistik">) {
  const staff = await getStaff();
  if (!staff) return null;
  const isSuper = staff.role === "superadmin";
  const permittedIds = staff.permissions.filter((p) => p.key === "analitik_gor").map((p) => p.schoolId);
  if (!isSuper && permittedIds.length === 0) {
    return <p className="text-sm">Bu sayfa analitik görme izni olanlar içindir.</p>;
  }

  const supabase = await createClient();
  const { data: schoolRows } = await supabase.from("clusters").select("id, name").eq("type", "school").order("name");
  const schools = (schoolRows ?? []).filter((s) => isSuper || permittedIds.includes(s.id));
  if (schools.length === 0) return <p className="text-sm">Görülebilecek okul yok.</p>;

  const query = await searchParams;
  const school = schools.find((s) => s.id === one(query.okul)) ?? schools[0];
  const metric = metrics.find((m) => m.key === one(query.olcut)) ?? metrics[0];
  const period = periods.find((p) => p.key === one(query.donem)) ?? periods[0];
  const href = (change: Record<string, string>) =>
    `/istatistik?${new URLSearchParams({ okul: school.id, olcut: metric.key, donem: period.key, ...change })}`;

  const [{ data: stats, error: statsError }, { data: board, error: boardError }] = await Promise.all([
    supabase.rpc("school_stats", { p_school_id: school.id }).single(),
    supabase.rpc("get_leaderboard", {
      p_metric: metric.key,
      p_period: period.period,
      p_weeks_ago: period.weeksAgo,
      p_school_id: school.id,
      p_limit: 50,
    }),
  ]);

  const cards = stats
    ? [
        { label: "Kayıtlı", value: formatAmount(stats.members) },
        { label: "Okul maili doğrulanmış", value: formatAmount(stats.verified_members) },
        { label: "Bu hafta bahse katılan", value: formatAmount(stats.active_this_week) },
        { label: "Bu hafta yatırım", value: formatAmount(stats.wagers_this_week) },
        { label: "Bu hafta yatırılan SP", value: formatAmount(stats.sp_staked_this_week) },
        { label: "Bu hafta yatırılan SSP", value: formatAmount(stats.ssp_staked_this_week) },
        { label: "Açık bahis", value: formatAmount(stats.open_bets) },
        { label: "Açık itiraz", value: formatAmount(stats.open_disputes) },
        { label: "Bu hafta görev ödülü", value: formatAmount(stats.quest_claims_this_week) },
        { label: "Bu hafta market satışı", value: formatAmount(stats.market_purchases_this_week) },
      ]
    : [];
  const computedAt = board?.[0]?.computed_at;

  return (
    <div className="flex flex-col gap-6">
      <div>
        <h1 className="text-2xl font-semibold">İstatistik</h1>
        <p className="text-sm text-zinc-500">
          Okul özeti istek anında sayılır; hafta pazartesi başlar (İstanbul). Sıralama 10 dakikada bir hesaplanır ve
          beceriyi öne çıkarır: isabet oranı, net kazanç, en uzun doğru tahmin serisi. Bahis sayısı sıralaması yoktur.
        </p>
      </div>

      {schools.length > 1 && (
        <nav className="flex flex-wrap gap-3 text-sm">
          {schools.map((s) => (
            <Link key={s.id} href={href({ okul: s.id })} className={s.id === school.id ? "font-semibold" : "underline"}>
              {s.name}
            </Link>
          ))}
        </nav>
      )}

      <section className="flex flex-col gap-3">
        <h2 className="text-lg font-semibold">
          {school.name}
          {stats && <span className="text-sm font-normal text-zinc-500"> · hafta başı {stats.week_start}</span>}
        </h2>
        {statsError && <p className="text-sm text-red-700">Özet alınamadı: {dbErrorMessage(statsError)}</p>}
        <dl className="grid grid-cols-2 gap-3 sm:grid-cols-5">
          {cards.map((c) => (
            <div key={c.label} className="rounded border border-zinc-200 p-3 dark:border-zinc-800">
              <dt className="text-xs text-zinc-500">{c.label}</dt>
              <dd className="text-lg font-semibold">{c.value}</dd>
            </div>
          ))}
        </dl>
      </section>

      <section className="flex flex-col gap-3">
        <h2 className="text-lg font-semibold">Liderlik</h2>
        <nav className="flex flex-wrap gap-3 text-sm">
          {periods.map((p) => (
            <Link key={p.key} href={href({ donem: p.key })} className={p.key === period.key ? "font-semibold" : "underline"}>
              {p.label}
            </Link>
          ))}
        </nav>
        <nav className="flex flex-wrap gap-3 text-sm">
          {metrics.map((m) => (
            <Link key={m.key} href={href({ olcut: m.key })} className={m.key === metric.key ? "font-semibold" : "underline"}>
              {m.label}
            </Link>
          ))}
        </nav>
        {boardError && <p className="text-sm text-red-700">Sıralama alınamadı: {dbErrorMessage(boardError)}</p>}
        {board && board.length === 0 && <p className="text-sm text-zinc-500">Bu dönemde sıralamaya giren yok.</p>}
        {board && board.length > 0 && (
          <table className="w-full text-sm">
            <thead className="text-left text-zinc-500">
              <tr>
                <th className="py-1 pr-3 font-normal">Sıra</th>
                <th className="py-1 pr-3 font-normal">Kişi</th>
                <th className="py-1 pr-3 font-normal">Seviye</th>
                <th className="py-1 font-normal">Değer</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-zinc-200 dark:divide-zinc-800">
              {board.map((row) => (
                <tr key={row.user_id}>
                  <td className="py-1 pr-3">{row.rank}</td>
                  <td className="py-1 pr-3">
                    {row.badge && <span className="mr-1">{row.badge}</span>}
                    {row.first_name} {row.last_name}
                    {row.title && <span className="ml-2 text-xs text-zinc-500">{row.title}</span>}
                  </td>
                  <td className="py-1 pr-3">{row.level}</td>
                  <td className="py-1">{formatValue(metric.key, row.value, row.sample)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
        {computedAt && <p className="text-xs text-zinc-500">Son hesaplama: {formatDateTime(computedAt)}</p>}
      </section>
    </div>
  );
}
