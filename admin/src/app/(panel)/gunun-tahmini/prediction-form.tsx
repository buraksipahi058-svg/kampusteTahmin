"use client";

import { useActionState } from "react";
import { ActionForm, FormAlert, SubmitButton, inputClass, type ActionState } from "@/components/ui";
import { createDailyPrediction } from "./actions";

type School = { id: string; name: string };

// Seçenekler her zaman Evet / Hayır; kişi başı üst sınır ekonomi ayarından gelir.
export function PredictionForm({ schools }: { schools: School[] }) {
  const [state, action, actionPending] = useActionState(createDailyPrediction, {} as ActionState);

  return (
    <ActionForm action={action} state={state} pending={actionPending} className="flex max-w-xl flex-col gap-3 rounded-xl border border-line bg-panel/90 p-4">
      <h2 className="font-medium">Yeni günün tahmini</h2>
      <label className="flex flex-col gap-1 text-sm">
        Okul
        <select name="school_id" required className={inputClass} defaultValue={schools[0]?.id}>
          {schools.map((s) => (
            <option key={s.id} value={s.id}>
              {s.name}
            </option>
          ))}
        </select>
      </label>
      <label className="flex flex-col gap-1 text-sm">
        Evet / hayır sorusu
        <input
          name="question"
          required
          minLength={3}
          maxLength={140}
          className={inputClass}
          placeholder="Bugün yemekhanede mercimek çorbası çıkar mı?"
        />
      </label>
      <label className="flex flex-col gap-1 text-sm">
        Açıklama (isteğe bağlı)
        <textarea name="description" maxLength={2000} rows={2} className={inputClass} />
      </label>
      <label className="flex flex-col gap-1 text-sm">
        Kapanış (İstanbul saati, en geç 7 gün sonra)
        <input name="locks_at" type="datetime-local" required className={inputClass} />
      </label>
      <FormAlert state={state} />
      <div>
        <SubmitButton pendingText="Açılıyor…">Tahmini aç</SubmitButton>
      </div>
    </ActionForm>
  );
}
