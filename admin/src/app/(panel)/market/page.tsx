import type { Metadata } from "next";
import Link from "next/link";
import { getStaff } from "@/lib/auth";
import { dbErrorMessage } from "@/lib/errors";
import { formatAmount, formatDateTime } from "@/lib/format";
import { createClient } from "@/lib/supabase/server";
import { ItemForm, ToggleItem } from "./item-form";
import { categoryLabels } from "./labels";

export const metadata: Metadata = { title: "Market · KampüsBet Yönetim" };

export default async function MarketPage() {
  const staff = await getStaff();
  if (!staff) return null;
  const managedSchoolIds = staff.permissions.filter((p) => p.key === "market_yonet").map((p) => p.schoolId);
  const isSuper = staff.role === "superadmin";
  if (!isSuper && managedSchoolIds.length === 0) {
    return <p className="text-sm">Bu sayfa market yönetme izni olanlar içindir.</p>;
  }

  const supabase = await createClient();
  // RLS: süperadmin hepsini, yetkili izinli okullarının ürünlerini (kapalılar dahil) ve satıştaki genel ürünleri görür.
  const [{ data: items, error }, { data: schools }] = await Promise.all([
    supabase
      .from("market_items")
      .select("id, name, description, category, icon, color, price, currency, available_from, available_until, active, min_level, school_id, school:clusters!school_id(name)")
      .order("active", { ascending: false })
      .order("currency")
      .order("price")
      .limit(300),
    supabase.from("clusters").select("id, name").eq("type", "school").order("name"),
  ]);
  const allowedSchools = (schools ?? []).filter((s) => isSuper || managedSchoolIds.includes(s.id));

  return (
    <div className="flex flex-col gap-6">
      <div>
        <h1 className="text-2xl font-semibold">Market</h1>
        <p className="text-sm text-zinc-500">
          Yalnızca kozmetik: hiçbir ürün bahis şansını, oranı ya da ödemeyi etkilemez. SP ürünleri normal vitrinde,
          SSP ürünleri özel vitrinde görünür. Bir öğrenci her ürünü bir kez alır; aynı türden bir ürünü kuşanabilir.
        </p>
      </div>
      <ItemForm schools={allowedSchools} isSuper={isSuper} />
      {error && <p className="text-sm text-red-700">Ürünler alınamadı: {dbErrorMessage(error)}</p>}
      <ul className="flex flex-col divide-y divide-zinc-200 dark:divide-zinc-800">
        {items?.map((item) => {
          const canManage = item.school_id == null ? isSuper : isSuper || managedSchoolIds.includes(item.school_id);
          return (
            <li key={item.id} className={`flex flex-wrap items-start justify-between gap-3 py-3 ${item.active ? "" : "opacity-50"}`}>
              <div className="flex items-start gap-3 text-sm">
                <span
                  className="mt-0.5 flex h-8 w-8 items-center justify-center rounded-full border-2 text-base"
                  style={{ borderColor: item.color ?? "transparent", color: item.color ?? undefined }}
                  aria-hidden
                >
                  {item.icon ?? "●"}
                </span>
                <div>
                  <p className="font-medium">
                    {item.name} · {formatAmount(item.price)} {item.currency}
                  </p>
                  <p className="text-zinc-500">
                    {categoryLabels[item.category]}
                    {item.min_level > 1 && ` · ${item.min_level}. seviyede açılır`}
                    {item.description && ` · ${item.description}`}
                  </p>
                  <p className="text-xs text-zinc-500">
                    {item.school?.name ?? "Tüm okullar"}
                    {item.available_from && ` · ${formatDateTime(item.available_from)}'den`}
                    {item.available_until && ` · ${formatDateTime(item.available_until)}'e kadar`}
                    {!item.active && " · satışta değil"}
                  </p>
                </div>
              </div>
              {canManage && (
                <div className="flex items-center gap-3">
                  <Link href={`/market/${item.id}`} className="text-sm underline">
                    Düzenle
                  </Link>
                  <ToggleItem id={item.id} active={item.active} />
                </div>
              )}
            </li>
          );
        })}
      </ul>
    </div>
  );
}
