import type { Metadata } from "next";
import Link from "next/link";
import { getStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { AchievementForm } from "../achievement-form";

export const metadata: Metadata = { title: "Başarımı düzenle · KampüsBet Yönetim" };

export default async function EditAchievementPage(props: PageProps<"/basarimlar/[id]">) {
  const { id } = await props.params;
  const staff = await getStaff();
  if (!staff) return null;
  if (staff.role !== "superadmin") return <p className="text-sm">Bu sayfa yalnızca süperadmin içindir.</p>;

  const supabase = await createClient();
  const { data: achievement } = await supabase
    .from("achievements")
    .select("id, key, category, title, description, icon, metric, target, tier, reward_sp, reward_xp, hidden, sort, active")
    .eq("id", id)
    .maybeSingle();

  return (
    <div className="flex flex-col gap-4">
      <Link href="/basarimlar" className="text-sm underline">
        ← Başarımlar
      </Link>
      {achievement ? <AchievementForm initial={achievement} /> : <p className="text-sm text-zinc-500">Başarım bulunamadı.</p>}
    </div>
  );
}
