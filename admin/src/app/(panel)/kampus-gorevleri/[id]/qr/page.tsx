import type { Metadata } from "next";
import Link from "next/link";
import { getStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { loadCampusQr } from "../../actions";
import { CampusQr, ResetCampusQr } from "../../campus-task-form";

export const metadata: Metadata = { title: "Kampüs görevi QR · KampüsBet Yönetim" };

// QR sayfası: basılı QR'ı yazdır ya da (dönen QR'da) mekândaki ekranda açık tut. Kodu yalnızca görevi yöneten alır.
export default async function CampusQrPage(props: PageProps<"/kampus-gorevleri/[id]/qr">) {
  const { id } = await props.params;
  const staff = await getStaff();
  if (!staff) return null;

  const supabase = await createClient();
  const { data: task } = await supabase.from("campus_tasks").select("id, title, icon, description").eq("id", id).maybeSingle();
  const qr = await loadCampusQr(id);

  return (
    <div className="flex flex-col items-center gap-4">
      <Link href="/kampus-gorevleri" className="self-start text-sm underline print:hidden">
        ← Kampüs görevleri
      </Link>
      {task && (
        <div className="text-center">
          <h1 className="text-2xl font-semibold">
            {task.icon} {task.title}
          </h1>
          {task.description && <p className="text-muted">{task.description}</p>}
          <p className="mt-1 text-sm">KampüsBet uygulamasında Oyunlar &gt; Kampüs görevleri &gt; QR okut</p>
        </div>
      )}
      <CampusQr taskId={id} initial={qr} />
      <div className="print:hidden">
        <ResetCampusQr id={id} />
      </div>
    </div>
  );
}
