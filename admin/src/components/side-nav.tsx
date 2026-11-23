"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  Award,
  ChartColumn,
  CircleQuestionMark,
  Coins,
  Flag,
  Gavel,
  Lightbulb,
  QrCode,
  ShieldCheck,
  Store,
  Trophy,
  UserCog,
  Users,
  type LucideIcon,
} from "lucide-react";

export type NavLink = { href: string; label: string };

// Sayfa → ikon (lucide: mobildeki Material Symbols Rounded'a yakın yuvarlak çizgi ikonlar).
const icons: Record<string, LucideIcon> = {
  "/istatistik": ChartColumn,
  "/resmi-bahisler": Trophy,
  "/gunun-tahmini": Lightbulb,
  "/itirazlar": Gavel,
  "/sosyal-bahisler": Users,
  "/kullanicilar": UserCog,
  "/trivia": CircleQuestionMark,
  "/gorevler": Flag,
  "/kampus-gorevleri": QrCode,
  "/market": Store,
  "/basarimlar": Award,
  "/yetkiler": ShieldCheck,
  "/bakiye": Coins,
};

/** Yan menü: etkin sayfa mor zeminli ve solunda ince çizgili; dar ekranda üstte yatay kayan şerit. Menü
 * geçişleri animasyonsuz (günde çok kullanılır). */
export function SideNav({ links }: { links: NavLink[] }) {
  const pathname = usePathname();
  return (
    <nav className="flex gap-1 overflow-x-auto md:flex-col md:overflow-visible">
      {links.map((l) => {
        const Icon = icons[l.href];
        const active = pathname === l.href || pathname.startsWith(`${l.href}/`);
        return (
          <Link
            key={l.href}
            href={l.href}
            aria-current={active ? "page" : undefined}
            className={[
              "relative flex shrink-0 items-center gap-2.5 whitespace-nowrap rounded-lg px-3 py-2 text-sm",
              "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/70",
              active
                ? "bg-primary-soft font-medium text-fg before:absolute before:inset-y-1.5 before:left-0 before:w-0.5 before:rounded-full before:bg-accent"
                : "text-muted hover:bg-panel-3 hover:text-fg",
            ].join(" ")}
          >
            {Icon && <Icon className={`size-4 shrink-0 ${active ? "text-accent" : ""}`} strokeWidth={2} aria-hidden />}
            {l.label}
          </Link>
        );
      })}
    </nav>
  );
}
