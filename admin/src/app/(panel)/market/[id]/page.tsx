import type { Metadata } from "next";
import Link from "next/link";
import { getStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { ItemForm } from "../item-form";

export const metadata: Metadata = { title: "Ürünü düzenle · KampüsBet Yönetim" };

export default async function EditItemPage(props: PageProps<"/market/[id]">) {
  const { id } = await props.params;
  const staff = await getStaff();
  if (!staff) return null;
  const managedSchoolIds = staff.permissions.filter((p) => p.key === "market_yonet").map((p) => p.schoolId);
  const isSuper = staff.role === "superadmin";

  const supabase = await createClient();
  const [{ data: item }, { data: schools }] = await Promise.all([
    supabase
      .from("market_items")
      .select("id, school_id, name, description, category, icon, color, price, currency, available_from, available_until, active, min_level")
      .eq("id", id)
      .maybeSingle(),
    supabase.from("clusters").select("id, name").eq("type", "school").order("name"),
  ]);
  const allowedSchools = (schools ?? []).filter((s) => isSuper || managedSchoolIds.includes(s.id));

  return (
    <div className="flex flex-col gap-4">
      <Link href="/market" className="text-sm underline">
        ← Market
      </Link>
      {item ? <ItemForm schools={allowedSchools} isSuper={isSuper} initial={item} /> : <p className="text-sm text-zinc-500">Ürün bulunamadı.</p>}
    </div>
  );
}
