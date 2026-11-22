"use client";

import { useActionState, useState } from "react";
import { ActionForm, FormAlert, SubmitButton, inputClass, type ActionState } from "@/components/ui";
import { saveQuestion, toggleQuestion } from "./actions";

type School = { id: string; name: string };

export function QuestionForm({ schools, canGlobal }: { schools: School[]; canGlobal: boolean }) {
  const [state, action, actionPending] = useActionState(saveQuestion, {} as ActionState);
  const [count, setCount] = useState(4);

  return (
    <ActionForm action={action} state={state} pending={actionPending} className="flex max-w-xl flex-col gap-3 rounded-lg border border-zinc-200 p-4 dark:border-zinc-800">
      <h2 className="font-medium">Yeni soru</h2>
      <label className="flex flex-col gap-1 text-sm">
        Kapsam
        <select name="school_id" className={inputClass} defaultValue={canGlobal ? "" : schools[0]?.id}>
          {canGlobal && <option value="">Tüm okullar (genel)</option>}
          {schools.map((s) => (
            <option key={s.id} value={s.id}>
              {s.name}
            </option>
          ))}
        </select>
      </label>
      <label className="flex flex-col gap-1 text-sm">
        Soru
        <input name="question" required minLength={5} maxLength={300} className={inputClass} />
      </label>
      <fieldset className="flex flex-col gap-2 text-sm">
        <legend className="mb-1">Şıklar (doğru olanı işaretle)</legend>
        {Array.from({ length: count }, (_, i) => (
          <div key={i} className="flex items-center gap-2">
            <input type="radio" name="correct" value={i} required defaultChecked={i === 0} aria-label={`${i + 1}. şık doğru`} />
            <input name="option" required maxLength={100} placeholder={`${i + 1}. şık`} className={`${inputClass} flex-1`} />
          </div>
        ))}
        <div className="flex gap-3">
          {count < 4 && (
            <button type="button" className="underline" onClick={() => setCount(count + 1)}>
              Şık ekle
            </button>
          )}
          {count > 2 && (
            <button type="button" className="underline" onClick={() => setCount(count - 1)}>
              Son şıkkı kaldır
            </button>
          )}
        </div>
      </fieldset>
      <label className="flex flex-col gap-1 text-sm">
        Kategori (isteğe bağlı)
        <input name="category" maxLength={50} className={inputClass} placeholder="Kampüs, Spor, Tarih…" />
      </label>
      <FormAlert state={state} />
      <div>
        <SubmitButton pendingText="Ekleniyor…">Soruyu ekle</SubmitButton>
      </div>
    </ActionForm>
  );
}

export function ToggleQuestion({ id, active }: { id: string; active: boolean }) {
  const [state, action, actionPending] = useActionState(toggleQuestion, {} as ActionState);
  return (
    <ActionForm action={action} state={state} pending={actionPending} className="flex items-center gap-2">
      <input type="hidden" name="id" value={id} />
      <SubmitButton tone="neutral" pendingText="…">
        {active ? "Kapat" : "Aç"}
      </SubmitButton>
      <FormAlert state={state} />
    </ActionForm>
  );
}
