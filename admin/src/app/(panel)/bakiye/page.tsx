import type { Metadata } from "next";
import { UserSearch, cleanQuery } from "@/components/user-search";
import { getStaff } from "@/lib/auth";
import { formatAmount, formatDateTime } from "@/lib/format";
import { createClient } from "@/lib/supabase/server";
import { BalanceForm } from "./balance-form";

export const metadata: Metadata = { title: "SSP ver / bakiye düzelt · KampüsBet Yönetim" };

export default async function BalancePage({ searchParams }: PageProps<"/bakiye">) {
  const staff = await getStaff();
  if (staff?.role !== "superadmin") return <p className="text-sm">Bu sayfa yalnızca süperadmin içindir.</p>;

  const q = cleanQuery((await searchParams).q);
  const supabase = await createClient();
  let query = supabase
    .from("profiles")
    .select("id, first_name, last_name, school:clusters!school_id(name)")
    .neq("id", staff.id)
    .order("first_name")
    .limit(50);
  if (q) query = query.or(`first_name.ilike.%${q}%,last_name.ilike.%${q}%`);
  const { data: users } = await query;

  const { data: recent } = await supabase
    .from("ledger_entries")
    .select(
      "id, currency, amount, reason, note, balance_after, created_at, user:profiles!user_id(first_name, last_name), actor:profiles!actor_id(first_name, last_name)",
    )
    .in("reason", ["admin_grant", "admin_adjust"])
    .order("id", { ascending: false })
    .limit(20);

  return (
    <div className="flex flex-col gap-6">
      <div>
        <h1 className="text-2xl font-semibold">SSP ver / bakiye düzelt</h1>
        <p className="text-sm text-muted">
          Yalnızca süperadmin. Gerekçe zorunlu, tek işlemde en fazla 1.000.000; kendi bakiyeni değiştiremezsin.
        </p>
      </div>
      <UserSearch q={q} />
      <BalanceForm
        users={(users ?? []).map((u) => ({ id: u.id, label: `${u.first_name} ${u.last_name} · ${u.school?.name ?? ""}` }))}
      />

      <section>
        <h2 className="mb-2 text-lg font-medium">Son yönetim işlemleri</h2>
        {recent?.length === 0 && <p className="text-sm text-muted">Henüz işlem yok.</p>}
        <ul className="flex flex-col gap-1 text-sm">
          {recent?.map((r) => (
            <li key={r.id}>
              {formatDateTime(r.created_at)} · {r.user?.first_name} {r.user?.last_name} ·{" "}
              <span className={r.amount > 0 ? "text-success" : "text-danger"}>
                {r.amount > 0 ? "+" : ""}
                {formatAmount(r.amount)} {r.currency}
              </span>{" "}
              (bakiye {formatAmount(r.balance_after)}) · {r.note} · {r.actor?.first_name} {r.actor?.last_name}
            </li>
          ))}
        </ul>
      </section>
    </div>
  );
}
