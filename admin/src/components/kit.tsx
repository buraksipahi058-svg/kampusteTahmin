import type { ReactNode } from "react";

/** Panelin görsel parçaları (sunucuda da kullanılabilir). Renkler globals.css tokenlarından; kurallar
 * docs/harita/tasarim.md: basınca %97, 150 ms ease-out, yalnızca transform / renk geçişi, odakta mor halka. */

type Tone = "primary" | "secondary" | "danger" | "ghost";

const toneClass: Record<Tone, string> = {
  primary:
    "bg-primary text-primary-fg hover:bg-primary-hover shadow-[0_0_0_1px_rgb(167_139_250/0.35),0_8px_24px_-10px_rgb(139_92_246/0.8)]",
  secondary: "border border-line-strong bg-panel-2 text-fg hover:bg-panel-3",
  danger: "bg-danger-strong text-white hover:bg-danger-strong/85",
  ghost: "text-muted hover:bg-panel-3 hover:text-fg",
};

/** Düğme / düğme gibi bağlantı sınıfı. */
export function buttonClass(tone: Tone = "primary", size: "sm" | "md" = "md") {
  const sizing = size === "sm" ? "px-2.5 py-1 text-xs" : "px-3.5 py-2 text-sm";
  return [
    "inline-flex items-center justify-center gap-1.5 rounded-lg font-medium",
    "transition-[transform,background-color,color] duration-150 ease-out active:scale-[0.97]",
    "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/70 focus-visible:ring-offset-2 focus-visible:ring-offset-bg",
    "disabled:pointer-events-none disabled:opacity-50",
    sizing,
    toneClass[tone],
  ].join(" ");
}

/** Metin girdisi / seçim kutusu. */
export const inputClass =
  "rounded-lg border border-line bg-panel-2 px-3 py-2 text-sm text-fg placeholder:text-muted/70 transition-colors duration-150 focus:border-primary focus:outline-none focus-visible:ring-2 focus-visible:ring-primary/40";

/** Panel (kart): ince kenarlık, koyu mor yüzey. */
export function Panel({ children, className = "" }: { children: ReactNode; className?: string }) {
  return <section className={`rounded-xl border border-line bg-panel/90 ${className}`}>{children}</section>;
}

/** Sayfa başlığı: başlık, açıklama, sağda eylemler. */
export function PageHeader({
  title,
  description,
  actions,
}: {
  title: ReactNode;
  description?: ReactNode;
  actions?: ReactNode;
}) {
  return (
    <header className="mb-6 flex flex-wrap items-end justify-between gap-3">
      <div className="min-w-0">
        <h1 className="text-2xl font-semibold tracking-tight text-fg">{title}</h1>
        {description && <p className="mt-1 max-w-[65ch] text-sm text-muted">{description}</p>}
      </div>
      {actions && <div className="flex shrink-0 items-center gap-2">{actions}</div>}
    </header>
  );
}

const badgeTone = {
  neutral: "border-line-strong text-muted",
  primary: "border-primary/50 bg-primary-soft text-fg",
  success: "border-success/40 bg-success/10 text-success",
  danger: "border-danger/40 bg-danger/10 text-danger",
  warning: "border-warning/40 bg-warning/10 text-warning",
};

/** Durum rozeti (açık, kapalı, bekliyor...). */
export function Badge({ children, tone = "neutral" }: { children: ReactNode; tone?: keyof typeof badgeTone }) {
  return (
    <span
      className={`inline-flex shrink-0 items-center whitespace-nowrap rounded-full border px-2 py-0.5 text-xs font-medium ${badgeTone[tone]}`}
    >
      {children}
    </span>
  );
}

/** Boş liste. */
export function EmptyState({ children }: { children: ReactNode }) {
  return (
    <div className="rounded-xl border border-dashed border-line px-4 py-10 text-center text-sm text-muted">{children}</div>
  );
}
