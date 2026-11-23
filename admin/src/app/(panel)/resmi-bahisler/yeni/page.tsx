import type { Metadata } from "next";
import Link from "next/link";
import { getStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { OfficialBetForm } from "./bet-form";

export const metadata: Metadata = { title: "Yeni resmi bahis · KampüsBet Yönetim" };

export default async function NewOfficialBetPage() {
  const staff = await getStaff();
  if (!staff) return null;

  // Süperadmin her okulda, yetkili resmi_bahis_ac izni olduğu okullarda açabilir.
  const openSchoolIds = staff.permissions.filter((p) => p.key === "resmi_bahis_ac").map((p) => p.schoolId);
  const supabase = await createClient();
  const { data: schools } = await supabase.from("clusters").select("id, name").eq("type", "school").order("name");
  const allowed = (schools ?? []).filter((s) => staff.role === "superadmin" || openSchoolIds.includes(s.id));

  return (
    <div className="flex flex-col gap-4">
      <Link href="/resmi-bahisler" className="text-sm underline">
        ← Resmi bahisler
      </Link>
      <h1 className="text-2xl font-semibold">Yeni resmi bahis</h1>
      {allowed.length === 0 ? (
        <p className="text-sm text-muted">Resmi bahis açma iznin olan bir okul yok.</p>
      ) : (
        <OfficialBetForm schools={allowed} />
      )}
    </div>
  );
}
