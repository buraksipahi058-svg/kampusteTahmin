"use client";

import { useActionState, useState } from "react";
import { FormAlert, SubmitButton, inputClass, type ActionState } from "@/components/ui";
import { isoToIstanbulLocal } from "@/lib/format";
import { saveItem, toggleItem } from "./actions";
import { categoryLabels, usesColor, type MarketCategory, type MarketItem } from "./labels";

type School = { id: string; name: string };

// Yeni ürün ya da (initial verilirse) düzenleme formu. Ürünün türü düzenlemede değişmez.
export function ItemForm({ schools, isSuper, initial }: { schools: School[]; isSuper: boolean; initial?: MarketItem }) {
  const [state, action] = useActionState(saveItem, {} as ActionState);
  const [category, setCategory] = useState<MarketCategory>(initial?.category ?? "title");

  return (
    <form action={action} className="flex max-w-xl flex-col gap-3 rounded-lg border border-zinc-200 p-4 dark:border-zinc-800">
      <h2 className="font-medium">{initial ? "Ürünü düzenle" : "Yeni ürün"}</h2>
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
      <div className="flex flex-wrap gap-3">
        <label className="flex flex-1 flex-col gap-1 text-sm">
          Ad
          <input name="name" required minLength={2} maxLength={60} defaultValue={initial?.name} className={inputClass} placeholder="Kehanet Ustası" />
        </label>
        <label className="flex flex-col gap-1 text-sm">
          Tür
          {initial ? (
            <>
              <input type="hidden" name="category" value={initial.category} />
              <span className="py-1.5">{categoryLabels[initial.category]} (değişmez)</span>
            </>
          ) : (
            <select name="category" className={inputClass} value={category} onChange={(e) => setCategory(e.target.value as MarketCategory)}>
              {Object.entries(categoryLabels).map(([value, label]) => (
                <option key={value} value={value}>
                  {label}
                </option>
              ))}
            </select>
          )}
        </label>
      </div>
      <label className="flex flex-col gap-1 text-sm">
        Açıklama (isteğe bağlı)
        <input name="description" maxLength={300} defaultValue={initial?.description ?? ""} className={inputClass} />
      </label>
      {usesColor(category) ? (
        <label className="flex items-center gap-2 text-sm">
          Renk
          <input name="color" type="color" required defaultValue={initial?.color ?? "#7E57C2"} className="h-8 w-14" />
        </label>
      ) : (
        <label className="flex flex-col gap-1 text-sm">
          Simge (emoji, isteğe bağlı)
          <input name="icon" maxLength={8} defaultValue={initial?.icon ?? ""} className={`${inputClass} w-24`} placeholder="🔮" />
        </label>
      )}
      <div className="flex flex-wrap gap-3">
        <label className="flex flex-col gap-1 text-sm">
          Fiyat
          <input name="price" type="number" min={1} max={100000} required defaultValue={initial?.price ?? 300} className={`${inputClass} w-28`} />
        </label>
        <label className="flex flex-col gap-1 text-sm">
          Para birimi
          <select name="currency" className={inputClass} defaultValue={initial?.currency ?? "SP"}>
            <option value="SP">SP (normal vitrin)</option>
            <option value="SSP">SSP (özel vitrin)</option>
          </select>
        </label>
      </div>
      <div className="flex flex-wrap gap-3">
        <label className="flex flex-col gap-1 text-sm">
          Satış başlangıcı (isteğe bağlı)
          <input name="available_from" type="datetime-local" defaultValue={isoToIstanbulLocal(initial?.available_from ?? null)} className={inputClass} />
        </label>
        <label className="flex flex-col gap-1 text-sm">
          Satış bitişi (isteğe bağlı, sezonluk ürün)
          <input name="available_until" type="datetime-local" defaultValue={isoToIstanbulLocal(initial?.available_until ?? null)} className={inputClass} />
        </label>
      </div>
      {initial && (
        <label className="flex items-center gap-2 text-sm">
          <input type="checkbox" name="active" defaultChecked={initial.active} />
          Satışta (öğrenciler görür)
        </label>
      )}
      <FormAlert state={state} />
      <div>
        <SubmitButton pendingText="Kaydediliyor…">{initial ? "Kaydet" : "Ürünü ekle"}</SubmitButton>
      </div>
    </form>
  );
}

export function ToggleItem({ id, active }: { id: string; active: boolean }) {
  const [state, action] = useActionState(toggleItem, {} as ActionState);
  return (
    <form action={action} className="flex items-center gap-2">
      <input type="hidden" name="id" value={id} />
      <SubmitButton tone="neutral" pendingText="…">
        {active ? "Satıştan kaldır" : "Satışa aç"}
      </SubmitButton>
      <FormAlert state={state} />
    </form>
  );
}
