import type { Metadata } from "next";
import Link from "next/link";
import { getStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { QuestForm } from "../quest-form";

export const metadata: Metadata = { title: "Görevi düzenle · KampüsBet Yönetim" };

export default async function EditQuestPage(props: PageProps<"/gorevler/[id]">) {
  const { id } = await props.params;
  const staff = await getStaff();
  if (!staff) return null;
  const managedSchoolIds = staff.permissions.filter((p) => p.key === "gorev_yonet").map((p) => p.schoolId);
  const isSuper = staff.role === "superadmin";

  const supabase = await createClient();
  const [{ data: quest }, { data: schools }] = await Promise.all([
    supabase
      .from("quests")
      .select("id, school_id, title, description, period, action, target, reward_currency, reward_amount, starts_at, ends_at, active")
      .eq("id", id)
      .maybeSingle(),
    supabase.from("clusters").select("id, name").eq("type", "school").order("name"),
  ]);
  const allowedSchools = (schools ?? []).filter((s) => isSuper || managedSchoolIds.includes(s.id));

  return (
    <div className="flex flex-col gap-4">
      <Link href="/gorevler" className="text-sm underline">
        ← Görevler
      </Link>
      {quest ? (
        <QuestForm schools={allowedSchools} isSuper={isSuper} initial={quest} />
      ) : (
        <p className="text-sm text-zinc-500">Görev bulunamadı.</p>
      )}
    </div>
  );
}
