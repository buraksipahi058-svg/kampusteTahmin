import type { Metadata } from "next";
import Link from "next/link";
import { getStaff } from "@/lib/auth";
import { dbErrorMessage } from "@/lib/errors";
import { createClient } from "@/lib/supabase/server";
import { QuestionForm, ToggleQuestion } from "./question-form";

export const metadata: Metadata = { title: "Trivia soruları · KampüsBet Yönetim" };

export default async function TriviaPage() {
  const staff = await getStaff();
  if (!staff) return null;
  const managedSchoolIds = staff.permissions.filter((p) => p.key === "trivia_yonet").map((p) => p.schoolId);
  const isSuper = staff.role === "superadmin";
  if (!isSuper && managedSchoolIds.length === 0) {
    return <p className="text-sm">Bu sayfa trivia sorularını yönetme izni olanlar içindir.</p>;
  }

  const supabase = await createClient();
  // RLS: süperadmin hepsini, yetkili izinli okullarının sorularını görür.
  const [{ data: questions, error }, { data: schools }] = await Promise.all([
    supabase
      .from("trivia_questions")
      .select("id, question, options, correct_index, category, active, school:clusters!school_id(name)")
      .order("created_at", { ascending: false })
      .limit(200),
    supabase.from("clusters").select("id, name").eq("type", "school").order("name"),
  ]);
  const allowedSchools = (schools ?? []).filter((s) => isSuper || managedSchoolIds.includes(s.id));

  return (
    <div className="flex flex-col gap-6">
      <div>
        <h1 className="text-2xl font-semibold">Trivia soruları</h1>
        <p className="text-sm text-zinc-500">
          Düellolarda rastgele seçilir. Doğru cevap öğrencilere hiç gönderilmez. Soruları yönetebilenler
          düello oynayamaz. Kullanılmış bir soruyu kapatmak devam eden düelloları etkilemez.
        </p>
      </div>
      <QuestionForm schools={allowedSchools} canGlobal={isSuper} />
      {error && <p className="text-sm text-red-700">Sorular alınamadı: {dbErrorMessage(error)}</p>}
      <ul className="flex flex-col divide-y divide-zinc-200 dark:divide-zinc-800">
        {questions?.map((q) => (
          <li key={q.id} className={`flex flex-wrap items-start justify-between gap-3 py-3 ${q.active ? "" : "opacity-50"}`}>
            <div className="text-sm">
              <p className="font-medium">{q.question}</p>
              <p className="text-zinc-500">
                {q.options.map((o, i) => (
                  <span key={i} className={i === q.correct_index ? "font-semibold text-green-700 dark:text-green-400" : ""}>
                    {i > 0 && " · "}
                    {o}
                  </span>
                ))}
              </p>
              <p className="text-xs text-zinc-500">
                {q.school?.name ?? "Tüm okullar"}
                {q.category && ` · ${q.category}`}
                {!q.active && " · kapalı"}
              </p>
            </div>
            <div className="flex items-center gap-3">
              <Link href={`/trivia/${q.id}`} className="text-sm underline">
                Düzenle
              </Link>
              <ToggleQuestion id={q.id} active={q.active} />
            </div>
          </li>
        ))}
      </ul>
    </div>
  );
}
