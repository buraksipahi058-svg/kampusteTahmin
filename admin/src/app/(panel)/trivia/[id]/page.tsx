import type { Metadata } from "next";
import { getStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { QuestionForm } from "../question-form";

export const metadata: Metadata = { title: "Soruyu düzenle · KampüsBet Yönetim" };

// Düzenleme: save_trivia_question p_id ile; yetkiyi veritabanı denetler (okul sorusu trivia_yonet, genel soru süperadmin).
export default async function EditQuestionPage({ params }: PageProps<"/trivia/[id]">) {
  const { id } = await params;
  const staff = await getStaff();
  if (!staff) return null;
  const isSuper = staff.role === "superadmin";
  const managedSchoolIds = staff.permissions.filter((p) => p.key === "trivia_yonet").map((p) => p.schoolId);

  const supabase = await createClient();
  const [{ data: question }, { data: schools }] = await Promise.all([
    supabase
      .from("trivia_questions")
      .select("id, school_id, question, options, correct_index, category, active")
      .eq("id", id)
      .maybeSingle(),
    supabase.from("clusters").select("id, name").eq("type", "school").order("name"),
  ]);
  if (!question) return <p className="text-sm">Soru bulunamadı.</p>;
  const allowedSchools = (schools ?? []).filter((s) => isSuper || managedSchoolIds.includes(s.id));

  return (
    <div className="flex flex-col gap-4">
      <h1 className="text-2xl font-semibold">Soruyu düzenle</h1>
      <p className="text-sm text-zinc-500">Değişiklik yeni düellolarda geçerli olur; başlamış düellolar etkilenmez.</p>
      <QuestionForm schools={allowedSchools} canGlobal={isSuper} initial={question} />
    </div>
  );
}
