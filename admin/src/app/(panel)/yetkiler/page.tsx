import type { Metadata } from "next";
import { UserSearch, cleanQuery } from "@/components/user-search";
import { getStaff, permissionLabels, type PermissionKey } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { PermissionRow } from "./permission-row";

export const metadata: Metadata = { title: "Yetkiler · KampüsBet Yönetim" };

const roleLabels = { student: "Öğrenci", yetkili: "Yetkili", superadmin: "Süperadmin" } as const;

export default async function PermissionsPage({ searchParams }: PageProps<"/yetkiler">) {
  const staff = await getStaff();
  if (staff?.role !== "superadmin") return <p className="text-sm">Bu sayfa yalnızca süperadmin içindir.</p>;

  const q = cleanQuery((await searchParams).q);
  const supabase = await createClient();
  let query = supabase
    .from("profiles")
    .select("id, first_name, last_name, role, school_id, school:clusters!school_id(name)")
    .order("first_name")
    .limit(50);
  if (q) query = query.or(`first_name.ilike.%${q}%,last_name.ilike.%${q}%`);
  const { data: users } = await query;

  const { data: permissions } = await supabase
    .from("permissions")
    .select("user_id, cluster_id, permission_key")
    .in("user_id", (users ?? []).map((u) => u.id));

  return (
    <div className="flex flex-col gap-4">
      <div>
        <h1 className="text-2xl font-semibold">Yetkiler</h1>
        <p className="text-sm text-muted">
          İzinler kişinin okuluna verilir. İzin alan öğrenci yetkili olur, izni kalmayınca öğrenciye döner.
          Her değişiklik denetim kaydına yazılır.
        </p>
      </div>
      <UserSearch q={q} />
      {users?.length === 0 && <p className="text-sm text-muted">Kullanıcı bulunamadı.</p>}
      <ul className="flex flex-col divide-y divide-line">
        {users?.map((u) => {
          const held = (permissions ?? [])
            .filter((p) => p.user_id === u.id && p.cluster_id === u.school_id)
            .map((p) => p.permission_key as PermissionKey);
          return (
            <li key={u.id} className="flex flex-col gap-2 py-3">
              <div className="text-sm">
                <span className="font-medium">
                  {u.first_name} {u.last_name}
                </span>{" "}
                <span className="text-muted">
                  · {u.school?.name} · {roleLabels[u.role]}
                </span>
              </div>
              {u.role === "superadmin" ? (
                <span className="text-sm text-muted">Süperadmin her işlemi yapabilir.</span>
              ) : (
                <PermissionRow userId={u.id} schoolId={u.school_id} held={held} labels={permissionLabels} />
              )}
            </li>
          );
        })}
      </ul>
    </div>
  );
}
