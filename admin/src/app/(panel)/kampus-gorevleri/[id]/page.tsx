import type { Metadata } from "next";
import Link from "next/link";
import { getStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { CampusTaskForm } from "../campus-task-form";
import { rewardLimits } from "../limits";

export const metadata: Metadata = { title: "Kampüs görevini düzenle · KampüsBet Yönetim" };

export default async function EditCampusTaskPage(props: PageProps<"/kampus-gorevleri/[id]">) {
  const { id } = await props.params;
  const staff = await getStaff();
  if (!staff) return null;
  const isSuper = staff.role === "superadmin";

  const supabase = await createClient();
  const [{ data: task }, { data: schools }, limits] = await Promise.all([
    supabase
      .from("campus_tasks")
      .select("id, school_id, title, description, icon, verification, period, reward_currency, reward_amount, reward_xp, quota, qr_rotation_seconds, starts_at, ends_at, active")
      .eq("id", id)
      .maybeSingle(),
    supabase.from("clusters").select("id, name").eq("type", "school").order("name"),
    rewardLimits(supabase, isSuper),
  ]);

  return (
    <div className="flex flex-col gap-4">
      <Link href="/kampus-gorevleri" className="text-sm underline">
        ← Kampüs görevleri
      </Link>
      {task ? (
        <CampusTaskForm schools={schools ?? []} isSuper={isSuper} limits={limits} initial={task} />
      ) : (
        <p className="text-sm text-zinc-500">Görev bulunamadı.</p>
      )}
    </div>
  );
}
