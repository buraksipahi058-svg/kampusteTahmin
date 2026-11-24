import "server-only";
import { cache } from "react";
import { redirect } from "next/navigation";
import type { Database } from "./supabase/database.types";
import { createClient } from "./supabase/server";

export type PermissionKey = Database["public"]["Enums"]["permission_key"];

export type Staff = {
  id: string;
  name: string;
  role: "yetkili" | "superadmin";
  schoolName: string;
  permissions: { schoolId: string; key: PermissionKey }[];
};

// Panelde oturum açan kişi. Oturum yoksa girişe yönlendirir; öğrenciyse null döner.
// Bu kontrol yalnızca arayüz içindir: her işlemin asıl yetki kontrolü veritabanındadır.
export const getStaff = cache(async (): Promise<Staff | null> => {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect("/giris");

  const { data: profile } = await supabase
    .from("profiles")
    .select("id, first_name, last_name, role, school:clusters!school_id(name)")
    .eq("id", user.id)
    .maybeSingle();
  if (!profile || profile.role === "student") return null;

  const { data: permissions } = await supabase
    .from("permissions")
    .select("cluster_id, permission_key")
    .eq("user_id", user.id);

  return {
    id: profile.id,
    name: `${profile.first_name} ${profile.last_name}`,
    role: profile.role,
    schoolName: profile.school?.name ?? "",
    permissions: (permissions ?? []).map((p) => ({ schoolId: p.cluster_id, key: p.permission_key })),
  };
});

export function can(staff: Staff, schoolId: string, key: PermissionKey): boolean {
  return staff.role === "superadmin" || staff.permissions.some((p) => p.schoolId === schoolId && p.key === key);
}

export const permissionLabels: Record<PermissionKey, string> = {
  resmi_bahis_ac: "Resmi bahis açma",
  resmi_bahis_kapat: "Resmi bahis kilitleme / sonuçlandırma / iptal",
  kullanici_bahsi_denetle: "Kullanıcı bahsi denetleme",
  market_yonet: "Market yönetimi",
  gorev_yonet: "Görev yönetimi",
  kullanici_yonet: "Kullanıcı yönetimi",
  analitik_gor: "Analitik görme",
  trivia_yonet: "Trivia sorularını yönetme (düello oynayamaz)",
  kampus_gorevi_yonet: "Kampüs görevlerini yönetme (ödül alamaz)",
  kelime_yonet: "Kampüs kelimesini yönetme (kelimeden ödül alamaz)",
};
