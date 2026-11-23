import type { Metadata } from "next";
import Link from "next/link";
import { getStaff } from "@/lib/auth";
import { dbErrorMessage } from "@/lib/errors";
import { formatAmount } from "@/lib/format";
import { createClient } from "@/lib/supabase/server";
import { AchievementForm, ToggleAchievement } from "./achievement-form";
import { categoryLabels, metricLabels, tierLabels } from "./labels";

export const metadata: Metadata = { title: "Başarımlar · KampüsBet Yönetim" };

// Başarımlar bütün okullarda ortaktır; yalnızca süperadmin yönetir. Kazanan sayısı tüm okullardan.
export default async function AchievementsPage() {
  const staff = await getStaff();
  if (!staff) return null;
  if (staff.role !== "superadmin") return <p className="text-sm">Bu sayfa yalnızca süperadmin içindir.</p>;

  const supabase = await createClient();
  const { data: achievements, error } = await supabase
    .from("achievements")
    .select("id, key, category, title, description, icon, metric, target, tier, reward_sp, reward_xp, hidden, sort, active, achievement_unlocks(count)")
    .order("active", { ascending: false })
    .order("sort")
    .order("key");

  return (
    <div className="flex flex-col gap-6">
      <div>
        <h1 className="text-2xl font-semibold">Başarımlar</h1>
        <p className="text-sm text-zinc-500">
          İlerleme sunucuda öğrencinin kayıtlarından hesaplanır; hedefe ulaşan öğrenci ödülü uygulamada kendisi alır
          (yalnızca SP + XP). &quot;Çok bahis yap&quot; baskısı yaratmamak için sayı başarımlarını düşük, becerininkileri
          yüksek tut. Silme yok, kapatılır; kazananlarda kalır.
        </p>
      </div>
      <AchievementForm />
      {error && <p className="text-sm text-red-700">Başarımlar alınamadı: {dbErrorMessage(error)}</p>}
      <ul className="flex flex-col divide-y divide-zinc-200 dark:divide-zinc-800">
        {achievements?.map((a) => (
          <li key={a.id} className={`flex flex-wrap items-start justify-between gap-3 py-3 ${a.active ? "" : "opacity-50"}`}>
            <div className="text-sm">
              <p className="font-medium">
                {a.icon} {a.title} · {tierLabels[a.tier]} · {formatAmount(a.reward_sp)} SP
                {a.reward_xp > 0 && ` · ${a.reward_xp} XP`}
                {a.hidden && " · gizli"}
              </p>
              <p className="text-zinc-500">
                {a.description} · {metricLabels[a.metric] ?? a.metric} ≥ {formatAmount(a.target)}
              </p>
              <p className="text-xs text-zinc-500">
                {categoryLabels[a.category]} · {a.key} · sıra {a.sort} · kazanan {a.achievement_unlocks[0]?.count ?? 0}
                {!a.active && " · kapalı"}
              </p>
            </div>
            <div className="flex items-center gap-3">
              <Link href={`/basarimlar/${a.id}`} className="text-sm underline">
                Düzenle
              </Link>
              <ToggleAchievement id={a.id} active={a.active} />
            </div>
          </li>
        ))}
      </ul>
    </div>
  );
}
