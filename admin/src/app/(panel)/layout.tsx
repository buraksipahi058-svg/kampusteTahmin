import Link from "next/link";
import { logout } from "../giris/actions";
import { getStaff } from "@/lib/auth";

// Panel her istekte oturumu okur; anlık gezinme (static shell) hedeflenmez.
export const instant = false;

export default async function PanelLayout({ children }: LayoutProps<"/">) {
  const staff = await getStaff();

  if (!staff) {
    return (
      <main className="mx-auto flex w-full max-w-md flex-1 flex-col justify-center gap-4 px-4 py-16">
        <h1 className="text-xl font-semibold">Bu panel yalnızca yetkililer içindir</h1>
        <p className="text-sm text-zinc-500">Hesabının yönetim yetkisi yok. Yetki süperadmin tarafından verilir.</p>
        <form action={logout}>
          <button className="text-sm underline">Çıkış yap</button>
        </form>
      </main>
    );
  }

  const isModerator = staff.role === "superadmin" || staff.permissions.some((p) => p.key === "kullanici_bahsi_denetle");
  const links = [
    ...(staff.role === "superadmin" || staff.permissions.some((p) => p.key === "analitik_gor")
      ? [{ href: "/istatistik", label: "İstatistik" }]
      : []),
    { href: "/resmi-bahisler", label: "Resmi bahisler" },
    ...(staff.role === "superadmin" ||
    staff.permissions.some((p) => p.key === "resmi_bahis_ac" || p.key === "resmi_bahis_kapat")
      ? [{ href: "/gunun-tahmini", label: "Günün tahmini" }]
      : []),
    ...(isModerator
      ? [
          { href: "/itirazlar", label: "İtirazlar" },
          { href: "/sosyal-bahisler", label: "Sosyal bahisler" },
          { href: "/kullanicilar", label: "Kullanıcılar" },
        ]
      : []),
    ...(staff.role === "superadmin" || staff.permissions.some((p) => p.key === "trivia_yonet")
      ? [{ href: "/trivia", label: "Trivia soruları" }]
      : []),
    ...(staff.role === "superadmin" || staff.permissions.some((p) => p.key === "gorev_yonet")
      ? [{ href: "/gorevler", label: "Görevler" }]
      : []),
    ...(staff.role === "superadmin" || staff.permissions.some((p) => p.key === "kampus_gorevi_yonet")
      ? [{ href: "/kampus-gorevleri", label: "Kampüs görevleri" }]
      : []),
    ...(staff.role === "superadmin" || staff.permissions.some((p) => p.key === "market_yonet")
      ? [{ href: "/market", label: "Market" }]
      : []),
    ...(staff.role === "superadmin"
      ? [
          { href: "/basarimlar", label: "Başarımlar" },
          { href: "/yetkiler", label: "Yetkiler" },
          { href: "/bakiye", label: "SSP ver / bakiye düzelt" },
        ]
      : []),
  ];

  return (
    <div className="flex flex-1 flex-col">
      <header className="border-b border-zinc-200 dark:border-zinc-800">
        <div className="mx-auto flex w-full max-w-5xl flex-wrap items-center gap-x-6 gap-y-2 px-4 py-3">
          <span className="font-semibold">KampüsBet Yönetim</span>
          <nav className="flex flex-wrap gap-4 text-sm">
            {links.map((l) => (
              <Link key={l.href} href={l.href} className="hover:underline">
                {l.label}
              </Link>
            ))}
          </nav>
          <div className="ml-auto flex items-center gap-3 text-sm text-zinc-500">
            <span>
              {staff.name} · {staff.role === "superadmin" ? "Süperadmin" : `Yetkili (${staff.schoolName})`}
            </span>
            <form action={logout}>
              <button className="underline">Çıkış</button>
            </form>
          </div>
        </div>
      </header>
      <main className="mx-auto w-full max-w-5xl flex-1 px-4 py-6">{children}</main>
    </div>
  );
}
