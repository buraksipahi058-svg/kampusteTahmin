"use client";

import { useActionState, useEffect, useState } from "react";
import { ActionForm, FormAlert, SubmitButton, inputClass, type ActionState } from "@/components/ui";
import { isoToIstanbulLocal } from "@/lib/format";
import { loadCampusQr, resetCampusQr, saveCampusTask, toggleCampusTask, type QrView } from "./actions";
import { periodLabels, rotationLabels, verificationLabels, type CampusTask } from "./labels";

type School = { id: string; name: string };

// Yeni kampüs görevi ya da (initial verilirse) düzenleme. Okul ve doğrulama yöntemi sonradan değişmez.
export function CampusTaskForm({ schools, isSuper, initial }: { schools: School[]; isSuper: boolean; initial?: CampusTask }) {
  const [state, action, pending] = useActionState(saveCampusTask, {} as ActionState);
  const [verification, setVerification] = useState(initial?.verification ?? "qr");

  return (
    <ActionForm action={action} state={state} pending={pending} className="flex max-w-xl flex-col gap-3 rounded-lg border border-zinc-200 p-4 dark:border-zinc-800">
      <h2 className="font-medium">{initial ? "Kampüs görevini düzenle" : "Yeni kampüs görevi"}</h2>
      {initial && <input type="hidden" name="id" value={initial.id} />}
      <div className="flex flex-wrap gap-3">
        <label className="flex flex-col gap-1 text-sm">
          Okul
          {initial ? (
            <>
              <input type="hidden" name="school_id" value={initial.school_id} />
              <span className="py-2">{schools.find((s) => s.id === initial.school_id)?.name ?? "—"}</span>
            </>
          ) : (
            <select name="school_id" className={inputClass} defaultValue={schools[0]?.id}>
              {schools.map((s) => (
                <option key={s.id} value={s.id}>
                  {s.name}
                </option>
              ))}
            </select>
          )}
        </label>
        <label className="flex flex-col gap-1 text-sm">
          Doğrulama
          {initial ? (
            <>
              <input type="hidden" name="verification" value={initial.verification} />
              <span className="py-2">{verificationLabels[initial.verification]}</span>
            </>
          ) : (
            <select
              name="verification"
              className={inputClass}
              value={verification}
              onChange={(e) => setVerification(e.target.value as typeof verification)}
            >
              {Object.entries(verificationLabels).map(([value, label]) => (
                <option key={value} value={value}>
                  {label}
                </option>
              ))}
            </select>
          )}
        </label>
      </div>
      <div className="flex flex-wrap gap-3">
        <label className="flex flex-col gap-1 text-sm">
          Simge
          <input name="icon" maxLength={8} defaultValue={initial?.icon ?? "📍"} className={`${inputClass} w-20`} />
        </label>
        <label className="flex flex-1 flex-col gap-1 text-sm">
          Başlık
          <input name="title" required minLength={3} maxLength={80} defaultValue={initial?.title} className={inputClass} placeholder="Yemekhanede öğle yemeği ye" />
        </label>
      </div>
      <label className="flex flex-col gap-1 text-sm">
        Açıklama (isteğe bağlı; öğrenci ne yapmalı, QR nerede)
        <input name="description" maxLength={300} defaultValue={initial?.description ?? ""} className={inputClass} placeholder="QR kasanın yanında." />
      </label>
      <div className="flex flex-wrap gap-3">
        <label className="flex flex-col gap-1 text-sm">
          Tekrar
          <select name="period" className={inputClass} defaultValue={initial?.period ?? "once"}>
            {Object.entries(periodLabels).map(([value, label]) => (
              <option key={value} value={value}>
                {label}
              </option>
            ))}
          </select>
        </label>
        {verification === "qr" && (
          <label className="flex flex-col gap-1 text-sm">
            QR türü
            <select name="qr_rotation_seconds" className={inputClass} defaultValue={String(initial?.qr_rotation_seconds ?? 0)}>
              {Object.entries(rotationLabels).map(([value, label]) => (
                <option key={value} value={value}>
                  {label}
                </option>
              ))}
            </select>
          </label>
        )}
        <label className="flex flex-col gap-1 text-sm">
          Kontenjan (boş: sınırsız)
          <input name="quota" type="number" min={1} max={100000} defaultValue={initial?.quota ?? ""} className={`${inputClass} w-32`} />
        </label>
      </div>
      <div className="flex flex-wrap gap-3">
        <label className="flex flex-col gap-1 text-sm">
          Ödül (1–1000)
          <input name="reward_amount" type="number" min={1} max={1000} required defaultValue={initial?.reward_amount ?? 20} className={`${inputClass} w-28`} />
        </label>
        <label className="flex flex-col gap-1 text-sm">
          Para birimi
          <select name="reward_currency" className={inputClass} defaultValue={initial?.reward_currency ?? "SP"}>
            <option value="SP">SP</option>
            {(isSuper || initial?.reward_currency === "SSP") && <option value="SSP">SSP (yalnızca süperadmin)</option>}
          </select>
        </label>
        <label className="flex flex-col gap-1 text-sm">
          XP (0–500)
          <input name="reward_xp" type="number" min={0} max={500} required defaultValue={initial?.reward_xp ?? 10} className={`${inputClass} w-24`} />
        </label>
      </div>
      <div className="flex flex-wrap gap-3">
        <label className="flex flex-col gap-1 text-sm">
          Başlangıç (isteğe bağlı)
          <input name="starts_at" type="datetime-local" defaultValue={isoToIstanbulLocal(initial?.starts_at ?? null)} className={inputClass} />
        </label>
        <label className="flex flex-col gap-1 text-sm">
          Bitiş (isteğe bağlı)
          <input name="ends_at" type="datetime-local" defaultValue={isoToIstanbulLocal(initial?.ends_at ?? null)} className={inputClass} />
        </label>
      </div>
      {initial && (
        <label className="flex items-center gap-2 text-sm">
          <input type="checkbox" name="active" defaultChecked={initial.active} />
          Açık (öğrenciler görür)
        </label>
      )}
      <FormAlert state={state} />
      <div>
        <SubmitButton pendingText="Kaydediliyor…">{initial ? "Kaydet" : "Görevi ekle"}</SubmitButton>
      </div>
    </ActionForm>
  );
}

export function ToggleCampusTask({ id, active }: { id: string; active: boolean }) {
  const [state, action, pending] = useActionState(toggleCampusTask, {} as ActionState);
  return (
    <ActionForm action={action} state={state} pending={pending} className="flex items-center gap-2">
      <input type="hidden" name="id" value={id} />
      <SubmitButton tone="neutral" pendingText="…">
        {active ? "Kapat" : "Aç"}
      </SubmitButton>
      <FormAlert state={state} />
    </ActionForm>
  );
}

export function ResetCampusQr({ id }: { id: string }) {
  const [state, action, pending] = useActionState(resetCampusQr, {} as ActionState);
  return (
    <ActionForm action={action} state={state} pending={pending} className="flex flex-wrap items-center gap-2">
      <input type="hidden" name="id" value={id} />
      <SubmitButton tone="danger" pendingText="Yenileniyor…">
        QR&apos;ı yenile (eski kod geçersiz olur)
      </SubmitButton>
      <FormAlert state={state} />
    </ActionForm>
  );
}

// QR görünümü: basılıda sabit; dönen QR'da süresi dolunca kendiliğinden yenilenir (mekândaki ekran için).
export function CampusQr({ taskId, initial }: { taskId: string; initial: QrView }) {
  const [view, setView] = useState(initial);

  useEffect(() => {
    if ("error" in view || view.rotationSeconds === 0 || !view.validUntil) return;
    const wait = Math.max(new Date(view.validUntil).getTime() - Date.now(), 1000);
    const timer = setTimeout(async () => setView(await loadCampusQr(taskId)), wait);
    return () => clearTimeout(timer);
  }, [view, taskId]);

  if ("error" in view) return <p className="text-sm text-red-700">{view.error}</p>;
  return (
    <div className="flex flex-col items-center gap-3">
      <div className="rounded-lg bg-white p-4" dangerouslySetInnerHTML={{ __html: view.svg }} />
      <p className="font-mono text-lg tracking-widest">{view.code}</p>
      {view.rotationSeconds > 0 && (
        <p className="text-sm text-zinc-500">Kod {view.rotationSeconds} saniyede bir değişir; bu sayfa kendiliğinden yenilenir.</p>
      )}
    </div>
  );
}
