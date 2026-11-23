import type { Metadata } from "next";
import Link from "next/link";
import { getStaff } from "@/lib/auth";
import { dbErrorMessage } from "@/lib/errors";
import { formatAmount, formatDateTime } from "@/lib/format";
import { createClient } from "@/lib/supabase/server";
import { CampusTaskForm, ToggleCampusTask } from "./campus-task-form";
import { periodLabels, rotationLabels, verificationLabels } from "./labels";

export const metadata: Metadata = { title: "Kampüs görevleri · KampüsBet Yönetim" };

// Kampüs görevleri: okulun yetkilisi (kampus_gorevi_yonet) ve süperadmin açar. QR görevinde ödül okutunca hemen,
// fotoğraflı görevde yetkili onaylayınca verilir. SSP ödülü yalnızca süperadmin.
export default async function CampusTasksPage() {
  const staff = await getStaff();
  if (!staff) return null;
  const managed = staff.permissions.filter((p) => p.key === "kampus_gorevi_yonet").map((p) => p.schoolId);
  const isSuper = staff.role === "superadmin";
  if (!isSuper && managed.length === 0) return <p className="text-sm">Bu sayfa kampüs görevi yönetme izni olanlar içindir.</p>;

  const supabase = await createClient();
  // RLS: yöneten okulun görevlerini (kapalılar dahil), süperadmin hepsini görür.
  const [{ data: tasks, error }, { data: schools }] = await Promise.all([
    supabase
      .from("campus_tasks")
      .select("id, school_id, title, description, icon, verification, period, reward_currency, reward_amount, reward_xp, quota, qr_rotation_seconds, starts_at, ends_at, active, school:clusters!school_id(name), campus_task_submissions(count)")
      .order("active", { ascending: false })
      .order("created_at", { ascending: false })
      .limit(200),
    supabase.from("clusters").select("id, name").eq("type", "school").order("name"),
  ]);
  const allowedSchools = (schools ?? []).filter((s) => isSuper || managed.includes(s.id));

  return (
    <div className="flex flex-col gap-6">
      <div>
        <h1 className="text-2xl font-semibold">Kampüs görevleri</h1>
        <p className="text-sm text-zinc-500">
          Öğrenci QR görevinde mekândaki kodu uygulamadan okutur ve ödülü hemen alır; kişi görevi dönem başına bir kez
          yapar. Basılı QR sızarsa &quot;QR&apos;ı yenile&quot; ile eskisini geçersiz kıl. Görevi yönetenler ödül alamaz.
        </p>
      </div>
      <CampusTaskForm schools={allowedSchools} isSuper={isSuper} />
      {error && <p className="text-sm text-red-700">Görevler alınamadı: {dbErrorMessage(error)}</p>}
      <ul className="flex flex-col divide-y divide-zinc-200 dark:divide-zinc-800">
        {tasks?.map((t) => (
          <li key={t.id} className={`flex flex-wrap items-start justify-between gap-3 py-3 ${t.active ? "" : "opacity-50"}`}>
            <div className="text-sm">
              <p className="font-medium">
                {t.icon} {t.title} · {formatAmount(t.reward_amount)} {t.reward_currency}
                {t.reward_xp > 0 && ` · ${t.reward_xp} XP`}
              </p>
              <p className="text-zinc-500">
                {verificationLabels[t.verification]} · {periodLabels[t.period]}
                {t.verification === "qr" && ` · ${rotationLabels[t.qr_rotation_seconds]}`}
                {t.description && ` · ${t.description}`}
              </p>
              <p className="text-xs text-zinc-500">
                {t.school?.name} · gönderi {t.campus_task_submissions[0]?.count ?? 0}
                {t.quota != null && ` · kontenjan ${t.quota}`}
                {t.starts_at && ` · başlangıç ${formatDateTime(t.starts_at)}`}
                {t.ends_at && ` · bitiş ${formatDateTime(t.ends_at)}`}
                {!t.active && " · kapalı"}
              </p>
            </div>
            <div className="flex items-center gap-3">
              {t.verification === "qr" && (
                <Link href={`/kampus-gorevleri/${t.id}/qr`} className="text-sm underline">
                  QR
                </Link>
              )}
              {(t.reward_currency !== "SSP" || isSuper) && (
                <>
                  <Link href={`/kampus-gorevleri/${t.id}`} className="text-sm underline">
                    Düzenle
                  </Link>
                  <ToggleCampusTask id={t.id} active={t.active} />
                </>
              )}
            </div>
          </li>
        ))}
      </ul>
    </div>
  );
}
