import type { Metadata } from "next";
import { Badge, PageHeader } from "@/components/kit";
import { getStaff } from "@/lib/auth";
import { dbErrorMessage } from "@/lib/errors";
import { formatDate, istanbulToday } from "@/lib/format";
import { createClient } from "@/lib/supabase/server";
import { DeleteWord, WordForm } from "./word-form";

export const metadata: Metadata = { title: "Kampüs kelimesi · KampüsBet Yönetim" };

export default async function WordsPage() {
  const staff = await getStaff();
  if (!staff) return null;
  const managedSchoolIds = staff.permissions.filter((p) => p.key === "kelime_yonet").map((p) => p.schoolId);
  const isSuper = staff.role === "superadmin";
  if (!isSuper && managedSchoolIds.length === 0) {
    return <p className="text-sm">Bu sayfa kampüs kelimesini yönetme izni olanlar içindir.</p>;
  }

  const supabase = await createClient();
  // list_word_puzzles: son 30 gün ve ileri tarihliler; yetkili yalnızca kendi okullarınınkini (genel kelimeyi değil).
  const [{ data: words, error }, { data: schools }] = await Promise.all([
    supabase.rpc("list_word_puzzles"),
    supabase.from("clusters").select("id, name").eq("type", "school").order("name"),
  ]);
  const allowedSchools = (schools ?? []).filter((s) => isSuper || managedSchoolIds.includes(s.id));
  const today = istanbulToday();

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title="Kampüs kelimesi"
        description="Her gün için bir kampüs kelimesi gir. Öğrenci 6 hakta bulmaya çalışır; ne kadar az hakta bulursa o kadar çok SP ve XP alır. Okulun kendi kelimesi yoksa o gün 'tüm okullar' kelimesi oynanır."
      />
      <WordForm schools={allowedSchools} canGlobal={isSuper} today={today} />
      {error && <p className="text-sm text-danger">Kelimeler alınamadı: {dbErrorMessage(error)}</p>}
      {words && words.length === 0 && <p className="text-sm text-muted">Henüz kelime girilmedi.</p>}
      <ul className="flex flex-col divide-y divide-line">
        {words?.map((w) => {
          const past = w.puzzle_date < today;
          return (
            <li key={w.id} className={`flex flex-wrap items-center justify-between gap-3 py-3 ${past ? "opacity-60" : ""}`}>
              <div className="flex flex-col gap-1 text-sm">
                <p className="flex flex-wrap items-center gap-2">
                  <span className="font-mono text-base font-semibold tracking-widest">{w.word}</span>
                  {w.puzzle_date === today && <Badge tone="primary">Bugün</Badge>}
                </p>
                {w.hint && <p className="text-xs">İpucu: {w.hint}</p>}
                <p className="text-xs text-muted">
                  {formatDate(w.puzzle_date)} · {w.school_name ?? "Tüm okullar"}
                  {w.players > 0 && ` · ${w.players} kişi oynadı, ${w.solvers} kişi buldu, ${w.first_try} kişi ilk tahminde`}
                </p>
              </div>
              {w.players === 0 && !past && <DeleteWord id={w.id} />}
            </li>
          );
        })}
      </ul>
    </div>
  );
}
