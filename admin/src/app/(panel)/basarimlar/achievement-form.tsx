"use client";

import { useActionState } from "react";
import { ActionForm, FormAlert, SubmitButton, inputClass, type ActionState } from "@/components/ui";
import { saveAchievement, toggleAchievement } from "./actions";
import { categoryLabels, metricLabels, tierLabels, type Achievement } from "./labels";

// Yeni başarım ya da (initial verilirse) düzenleme formu. Anahtar düzenlemede değişmez.
export function AchievementForm({ initial }: { initial?: Achievement }) {
  const [state, action, pending] = useActionState(saveAchievement, {} as ActionState);

  return (
    <ActionForm action={action} state={state} pending={pending} className="flex max-w-xl flex-col gap-3 rounded-lg border border-zinc-200 p-4 dark:border-zinc-800">
      <h2 className="font-medium">{initial ? "Başarımı düzenle" : "Yeni başarım"}</h2>
      {initial && <input type="hidden" name="id" value={initial.id} />}
      <div className="flex flex-wrap gap-3">
        <label className="flex flex-col gap-1 text-sm">
          Anahtar
          <input
            name="key"
            required
            pattern="[a-z0-9_]{3,40}"
            defaultValue={initial?.key}
            readOnly={!!initial}
            className={`${inputClass} w-44 ${initial ? "opacity-60" : ""}`}
            placeholder="yeni_basarim"
          />
        </label>
        <label className="flex flex-col gap-1 text-sm">
          Simge
          <input name="icon" required maxLength={8} defaultValue={initial?.icon ?? "🏅"} className={`${inputClass} w-20`} />
        </label>
        <label className="flex flex-col gap-1 text-sm">
          Kategori
          <select name="category" className={inputClass} defaultValue={initial?.category ?? "prediction"}>
            {Object.entries(categoryLabels).map(([value, label]) => (
              <option key={value} value={value}>
                {label}
              </option>
            ))}
          </select>
        </label>
      </div>
      <label className="flex flex-col gap-1 text-sm">
        Ad
        <input name="title" required minLength={2} maxLength={40} defaultValue={initial?.title} className={inputClass} placeholder="Keskin Göz" />
      </label>
      <label className="flex flex-col gap-1 text-sm">
        Açıklama (öğrenci ne yapmalı)
        <input name="description" required minLength={3} maxLength={200} defaultValue={initial?.description} className={inputClass} placeholder="10 tahmini doğru bil." />
      </label>
      <div className="flex flex-wrap gap-3">
        <label className="flex flex-col gap-1 text-sm">
          Ölçüt
          <select name="metric" className={inputClass} defaultValue={initial?.metric ?? "correct"}>
            {Object.entries(metricLabels).map(([value, label]) => (
              <option key={value} value={value}>
                {label}
              </option>
            ))}
          </select>
        </label>
        <label className="flex flex-col gap-1 text-sm">
          Hedef
          <input name="target" type="number" min={1} max={100000} required defaultValue={initial?.target ?? 10} className={`${inputClass} w-28`} />
        </label>
        <label className="flex flex-col gap-1 text-sm">
          Kademe
          <select name="tier" className={inputClass} defaultValue={String(initial?.tier ?? 1)}>
            {Object.entries(tierLabels).map(([value, label]) => (
              <option key={value} value={value}>
                {label}
              </option>
            ))}
          </select>
        </label>
      </div>
      <div className="flex flex-wrap gap-3">
        <label className="flex flex-col gap-1 text-sm">
          SP ödülü (1–1000)
          <input name="reward_sp" type="number" min={1} max={1000} required defaultValue={initial?.reward_sp ?? 50} className={`${inputClass} w-28`} />
        </label>
        <label className="flex flex-col gap-1 text-sm">
          XP (0–500)
          <input name="reward_xp" type="number" min={0} max={500} required defaultValue={initial?.reward_xp ?? 20} className={`${inputClass} w-28`} />
        </label>
        <label className="flex flex-col gap-1 text-sm">
          Sıra (küçük önce)
          <input name="sort" type="number" required defaultValue={initial?.sort ?? 100} className={`${inputClass} w-24`} />
        </label>
      </div>
      <label className="flex items-center gap-2 text-sm">
        <input type="checkbox" name="hidden" defaultChecked={initial?.hidden ?? false} />
        Gizli (adı ve açıklaması kazanılınca açılır)
      </label>
      {initial && (
        <label className="flex items-center gap-2 text-sm">
          <input type="checkbox" name="active" defaultChecked={initial.active} />
          Açık (kapalı başarım yalnızca kazanmış olanlarda görünür)
        </label>
      )}
      <FormAlert state={state} />
      <div>
        <SubmitButton pendingText="Kaydediliyor…">{initial ? "Kaydet" : "Başarımı ekle"}</SubmitButton>
      </div>
    </ActionForm>
  );
}

export function ToggleAchievement({ id, active }: { id: string; active: boolean }) {
  const [state, action, pending] = useActionState(toggleAchievement, {} as ActionState);
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
