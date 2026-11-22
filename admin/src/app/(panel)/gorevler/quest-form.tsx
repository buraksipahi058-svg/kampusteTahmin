"use client";

import { useActionState } from "react";
import { FormAlert, SubmitButton, inputClass, type ActionState } from "@/components/ui";
import { isoToIstanbulLocal } from "@/lib/format";
import { saveQuest, toggleQuest } from "./actions";
import { actionLabels, periodHints, periodLabels, type Quest } from "./labels";

type School = { id: string; name: string };

// Yeni görev ya da (initial verilirse) düzenleme formu.
export function QuestForm({
  schools,
  isSuper,
  initial,
}: {
  schools: School[];
  isSuper: boolean;
  initial?: Quest;
}) {
  const [state, action] = useActionState(saveQuest, {} as ActionState);

  return (
    <form action={action} className="flex max-w-xl flex-col gap-3 rounded-lg border border-zinc-200 p-4 dark:border-zinc-800">
      <h2 className="font-medium">{initial ? "Görevi düzenle" : "Yeni görev"}</h2>
      {initial && <input type="hidden" name="id" value={initial.id} />}
      <label className="flex flex-col gap-1 text-sm">
        Kapsam
        <select name="school_id" className={inputClass} defaultValue={initial ? (initial.school_id ?? "") : isSuper ? "" : schools[0]?.id}>
          {isSuper && <option value="">Tüm okullar (genel)</option>}
          {schools.map((s) => (
            <option key={s.id} value={s.id}>
              {s.name}
            </option>
          ))}
        </select>
      </label>
      <label className="flex flex-col gap-1 text-sm">
        Başlık
        <input name="title" required minLength={3} maxLength={80} defaultValue={initial?.title} className={inputClass} placeholder="İki bahse katıl" />
      </label>
      <label className="flex flex-col gap-1 text-sm">
        Açıklama (isteğe bağlı)
        <input name="description" maxLength={300} defaultValue={initial?.description ?? ""} className={inputClass} />
      </label>
      <div className="flex flex-wrap gap-3">
        <label className="flex flex-col gap-1 text-sm">
          Dönem
          <select name="period" className={inputClass} defaultValue={initial?.period ?? "daily"}>
            {Object.entries(periodLabels).map(([value, label]) => (
              <option key={value} value={value}>
                {label} — {periodHints[value as keyof typeof periodHints]}
              </option>
            ))}
          </select>
        </label>
        <label className="flex flex-col gap-1 text-sm">
          Eylem
          <select name="action" className={inputClass} defaultValue={initial?.action ?? "wager"}>
            {Object.entries(actionLabels).map(([value, label]) => (
              <option key={value} value={value}>
                {label}
              </option>
            ))}
          </select>
        </label>
        <label className="flex flex-col gap-1 text-sm">
          Hedef (kaç kez)
          <input name="target" type="number" min={1} max={100} required defaultValue={initial?.target ?? 1} className={`${inputClass} w-24`} />
        </label>
      </div>
      <div className="flex flex-wrap gap-3">
        <label className="flex flex-col gap-1 text-sm">
          Ödül
          <input name="reward_amount" type="number" min={1} max={1000} required defaultValue={initial?.reward_amount ?? 20} className={`${inputClass} w-28`} />
        </label>
        <label className="flex flex-col gap-1 text-sm">
          Para birimi
          <select name="reward_currency" className={inputClass} defaultValue={initial?.reward_currency ?? "SP"}>
            <option value="SP">SP</option>
            {isSuper && <option value="SSP">SSP (yalnızca süperadmin)</option>}
          </select>
        </label>
        <label className="flex flex-col gap-1 text-sm">
          XP (paradan ayrı, 0–1000)
          <input name="reward_xp" type="number" min={0} max={1000} required defaultValue={initial?.reward_xp ?? 20} className={`${inputClass} w-28`} />
        </label>
      </div>
      <div className="flex flex-wrap gap-3">
        <label className="flex flex-col gap-1 text-sm">
          Başlangıç (isteğe bağlı; sezonlukta zorunlu)
          <input name="starts_at" type="datetime-local" defaultValue={isoToIstanbulLocal(initial?.starts_at ?? null)} className={inputClass} />
        </label>
        <label className="flex flex-col gap-1 text-sm">
          Bitiş (isteğe bağlı; sezonlukta zorunlu)
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
    </form>
  );
}

export function ToggleQuest({ id, active }: { id: string; active: boolean }) {
  const [state, action] = useActionState(toggleQuest, {} as ActionState);
  return (
    <form action={action} className="flex items-center gap-2">
      <input type="hidden" name="id" value={id} />
      <SubmitButton tone="neutral" pendingText="…">
        {active ? "Kapat" : "Aç"}
      </SubmitButton>
      <FormAlert state={state} />
    </form>
  );
}
