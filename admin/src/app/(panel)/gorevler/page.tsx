import type { Metadata } from "next";
import Link from "next/link";
import { getStaff } from "@/lib/auth";
import { dbErrorMessage } from "@/lib/errors";
import { formatAmount, formatDateTime } from "@/lib/format";
import { createClient } from "@/lib/supabase/server";
import { actionLabels, periodLabels } from "./labels";
import { QuestForm, ToggleQuest } from "./quest-form";

export const metadata: Metadata = { title: "Görevler · KampüsBet Yönetim" };

export default async function QuestsPage() {
  const staff = await getStaff();
  if (!staff) return null;
  const managedSchoolIds = staff.permissions.filter((p) => p.key === "gorev_yonet").map((p) => p.schoolId);
  const isSuper = staff.role === "superadmin";
  if (!isSuper && managedSchoolIds.length === 0) {
    return <p className="text-sm">Bu sayfa görev yönetme izni olanlar içindir.</p>;
  }

  const supabase = await createClient();
  // RLS: süperadmin hepsini, yetkili izinli okullarının görevlerini (kapalılar dahil) ve açık genel görevleri görür.
  const [{ data: quests, error }, { data: schools }] = await Promise.all([
    supabase
      .from("quests")
      .select("id, title, description, period, action, target, reward_currency, reward_amount, starts_at, ends_at, active, school_id, school:clusters!school_id(name)")
      .order("active", { ascending: false })
      .order("created_at", { ascending: false })
      .limit(200),
    supabase.from("clusters").select("id, name").eq("type", "school").order("name"),
  ]);
  const allowedSchools = (schools ?? []).filter((s) => isSuper || managedSchoolIds.includes(s.id));

  return (
    <div className="flex flex-col gap-6">
      <div>
        <h1 className="text-2xl font-semibold">Görevler</h1>
        <p className="text-sm text-zinc-500">
          İlerleme sunucuda öğrencinin kayıtlarından sayılır; ödülü öğrenci uygulamadan alır, dönem başına bir kez.
          Tüm okullara görev ve SSP ödülü yalnızca süperadmin içindir. Bahis sayısını öne çıkaran görevlerde ödülü
          küçük tut (MIMARI §11).
        </p>
      </div>
      <QuestForm schools={allowedSchools} isSuper={isSuper} />
      {error && <p className="text-sm text-red-700">Görevler alınamadı: {dbErrorMessage(error)}</p>}
      <ul className="flex flex-col divide-y divide-zinc-200 dark:divide-zinc-800">
        {quests?.map((q) => {
          const canManage = q.school_id == null ? isSuper : isSuper || managedSchoolIds.includes(q.school_id);
          return (
            <li key={q.id} className={`flex flex-wrap items-start justify-between gap-3 py-3 ${q.active ? "" : "opacity-50"}`}>
              <div className="text-sm">
                <p className="font-medium">
                  {q.title} · {formatAmount(q.reward_amount)} {q.reward_currency}
                </p>
                <p className="text-zinc-500">
                  {periodLabels[q.period]} · {actionLabels[q.action]} × {q.target}
                  {q.description && ` · ${q.description}`}
                </p>
                <p className="text-xs text-zinc-500">
                  {q.school?.name ?? "Tüm okullar"}
                  {q.starts_at && ` · ${formatDateTime(q.starts_at)}'den`}
                  {q.ends_at && ` · ${formatDateTime(q.ends_at)}'e kadar`}
                  {!q.active && " · kapalı"}
                </p>
              </div>
              {canManage && (
                <div className="flex items-center gap-3">
                  <Link href={`/gorevler/${q.id}`} className="text-sm underline">
                    Düzenle
                  </Link>
                  <ToggleQuest id={q.id} active={q.active} />
                </div>
              )}
            </li>
          );
        })}
      </ul>
    </div>
  );
}
