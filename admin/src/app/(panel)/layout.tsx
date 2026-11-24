import { LogOut } from "lucide-react";
import Image from "next/image";
import Link from "next/link";
import { connection } from "next/server";
import { logout } from "../giris/actions";
import { buttonClass } from "@/components/kit";
import { SideNav } from "@/components/side-nav";
import { getStaff } from "@/lib/auth";

// Panel her istekte oturumu okur; anlık gezinme (static shell) hedeflenmez.
export const instant = false;

export default async function PanelLayout({ children }: LayoutProps<"/">) {
  // İstek anında çizilir: Supabase oturumu Date.now() kullanır; önceden çizim (prerender) sırasında çağrılmasın.
  await connection();
  const staff = await getStaff();

  if (!staff) {
    return (
      <main className="mx-auto flex w-full max-w-md flex-1 flex-col justify-center gap-4 px-4 py-16">
        <h1 className="text-xl font-semibold">Bu panel yalnızca yetkililer içindir</h1>
        <p className="text-sm text-muted">Hesabının yönetim yetkisi yok. Yetki süperadmin tarafından verilir.</p>
        <form action={logout}>
          <button className={buttonClass("secondary")}>Çıkış yap</button>
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
    ...(staff.role === "superadmin" || staff.permissions.some((p) => p.key === "kelime_yonet")
      ? [{ href: "/kelimeler", label: "Kampüs kelimesi" }]
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
    <div className="flex flex-1 flex-col md:flex-row">
      {/* Yan menü: logo, sayfalar (etkin olan vurgulu), altta kişi ve çıkış. Dar ekranda üstte şerit. */}
      <aside className="flex flex-col gap-4 border-b border-line bg-panel/80 p-3 backdrop-blur md:sticky md:top-0 md:h-screen md:w-64 md:shrink-0 md:border-r md:border-b-0 md:p-4">
        <Link href="/" className="flex items-center gap-2.5 px-1">
          <Image src="/logo.png" alt="" width={36} height={32} className="h-8 w-auto" priority />
          <span className="font-semibold tracking-tight">
            KampüsBet <span className="text-muted">Yönetim</span>
          </span>
        </Link>
        <div className="md:flex-1 md:overflow-y-auto">
          <SideNav links={links} />
        </div>
        <div className="hidden border-t border-line pt-3 md:block">
          <p className="truncate text-sm font-medium" title={staff.name}>
            {staff.name}
          </p>
          <p className="truncate text-xs text-muted">
            {staff.role === "superadmin" ? "Süperadmin" : `Yetkili · ${staff.schoolName}`}
          </p>
          <form action={logout} className="mt-2">
            <button className={buttonClass("ghost", "sm")}>
              <LogOut className="size-3.5" aria-hidden />
              Çıkış
            </button>
          </form>
        </div>
      </aside>
      <main className="mx-auto w-full max-w-5xl flex-1 px-4 py-6 md:px-8 md:py-8">{children}</main>
    </div>
  );
}
