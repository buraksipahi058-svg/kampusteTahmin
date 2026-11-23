import type { Metadata } from "next";
import { UserSearch, cleanQuery } from "@/components/user-search";
import { can, getStaff } from "@/lib/auth";
import { dbErrorMessage } from "@/lib/errors";
import { formatDateTime } from "@/lib/format";
import { createClient } from "@/lib/supabase/server";
import { UserActions } from "./user-actions";

export const metadata: Metadata = { title: "Kullanıcılar · KampüsBet Yönetim" };

const roleLabels = { student: "Öğrenci", yetkili: "Yetkili", superadmin: "Süperadmin" } as const;

// Süperadmin: herkesi görür, yasaklar / yasağı kaldırır. Moderatör (kullanici_bahsi_denetle): kendi okulunun
// kişilerini görür, hakem ihtarını sıfırlar. Yetkiyi her işlemde veritabanı denetler.
export default async function UsersPage({ searchParams }: PageProps<"/kullanicilar">) {
  const staff = await getStaff();
  const isSuper = staff?.role === "superadmin";
  const isModerator = staff?.permissions.some((p) => p.key === "kullanici_bahsi_denetle") ?? false;
  if (!staff || (!isSuper && !isModerator)) {
    return <p className="text-sm">Bu sayfa süperadmin ve moderatörler içindir.</p>;
  }

  const q = cleanQuery((await searchParams).q);
  const supabase = await createClient();
  let query = supabase
    .from("profiles")
    .select("id, first_name, last_name, role, referee_strikes, school_id, school:clusters!school_id(name)")
    .is("deleted_at", null)
    .neq("id", staff.id)
    .order("first_name", { ascending: true })
    .limit(50);
  if (q) query = query.or(`first_name.ilike.%${q}%,last_name.ilike.%${q}%`);
  const { data: users, error } = await query;
  // Yasak bilgisi profilde istemciye kapalı; yalnızca yetkili olduğu kişiler için ayrı sorgu.
  const { data: bans } = users?.length
    ? await supabase.rpc("banned_users", { p_user_ids: users.map((u) => u.id) })
    : { data: [] };
  const bannedAt = new Map((bans ?? []).map((b) => [b.user_id, b.banned_at]));

  return (
    <div className="flex flex-col gap-6">
      <div>
        <h1 className="text-2xl font-semibold">Kullanıcılar</h1>
        <p className="text-sm text-muted">
          Yasaklanan kişinin oturumları hemen kapanır ve uygulamaya giremez; gerekçe yalnızca denetim kaydında tutulur.
          Hakem ihtarı {"≥"} sınır olan kişi sosyal bahis açamaz ve hakem olamaz.
        </p>
      </div>
      <UserSearch q={q} />
      {error && <p className="text-sm text-danger">Kullanıcılar alınamadı: {dbErrorMessage(error)}</p>}
      {users?.length === 0 && <p className="text-sm text-muted">Kimse bulunamadı.</p>}
      <ul className="flex flex-col divide-y divide-line">
        {users?.map((u) => {
          const banned = bannedAt.get(u.id);
          return (
          <li key={u.id} className="flex flex-wrap items-start justify-between gap-3 py-3 text-sm">
            <div>
              <p className="font-medium">
                {u.first_name} {u.last_name}
                {banned && <span className="ml-2 text-danger">yasaklı</span>}
              </p>
              <p className="text-muted">
                {u.school?.name} · {roleLabels[u.role]} · hakem ihtarı {u.referee_strikes}
                {banned && ` · yasak: ${formatDateTime(banned)}`}
              </p>
            </div>
            <UserActions
              userId={u.id}
              banned={banned != null}
              strikes={u.referee_strikes}
              canBan={isSuper && u.role !== "superadmin"}
              canForgive={can(staff, u.school_id, "kullanici_bahsi_denetle")}
            />
          </li>
          );
        })}
      </ul>
    </div>
  );
}
