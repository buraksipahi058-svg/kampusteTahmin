"use client";

import { useActionState } from "react";
import { ActionForm, FormAlert, SubmitButton, inputClass, type ActionState } from "@/components/ui";
import { deleteWord, saveWord } from "./actions";

type School = { id: string; name: string };

export function WordForm({ schools, canGlobal, today }: { schools: School[]; canGlobal: boolean; today: string }) {
  const [state, action, actionPending] = useActionState(saveWord, {} as ActionState);

  return (
    <ActionForm
      action={action}
      state={state}
      pending={actionPending}
      className="flex max-w-xl flex-col gap-3 rounded-xl border border-line bg-panel/90 p-4"
    >
      <h2 className="font-medium">Yeni kelime</h2>
      <label className="flex flex-col gap-1 text-sm">
        Kapsam
        <select name="school_id" className={inputClass} defaultValue={canGlobal ? "" : schools[0]?.id}>
          {canGlobal && <option value="">Tüm okullar (okulun kendi kelimesi yoksa)</option>}
          {schools.map((s) => (
            <option key={s.id} value={s.id}>
              {s.name}
            </option>
          ))}
        </select>
      </label>
      <div className="flex flex-wrap gap-3">
        <label className="flex flex-col gap-1 text-sm">
          Gün
          <input type="date" name="date" required min={today} defaultValue={today} className={inputClass} />
        </label>
        <label className="flex flex-1 flex-col gap-1 text-sm">
          Kelime (4–8 harf)
          <input
            name="word"
            required
            minLength={4}
            maxLength={8}
            autoComplete="off"
            placeholder="KAMPÜS"
            className={`${inputClass} font-mono uppercase tracking-widest`}
          />
        </label>
      </div>
      <label className="flex flex-col gap-1 text-sm">
        İpucu (isteğe bağlı, 3. tahminden sonra görünür)
        <input
          name="hint"
          minLength={3}
          maxLength={140}
          autoComplete="off"
          placeholder="Öğle arası kuyruğun olduğu yer"
          className={inputClass}
        />
      </label>
      <p className="text-xs text-muted">
        Öğrenciler kelimeyi ve ipucunu zamanı gelmeden göremez; tahminler sunucuda işaretlenir. Tahminler sözlükte
        olmalıdır; girdiğin kelime sözlükte yoksa eklenir. Kelimeyi giren ya da bu listede gören, o kelimeden ödül
        alamaz. Bugün bütün okullar için kelime varsa okula ancak yarından itibaren kelime girilebilir.
      </p>
      <div className="flex items-center gap-3">
        <SubmitButton>Kaydet</SubmitButton>
        <FormAlert state={state} />
      </div>
    </ActionForm>
  );
}

export function DeleteWord({ id }: { id: string }) {
  const [state, action, actionPending] = useActionState(deleteWord, {} as ActionState);
  return (
    <ActionForm action={action} state={state} pending={actionPending} className="flex items-center gap-2">
      <input type="hidden" name="id" value={id} />
      <SubmitButton tone="neutral" pendingText="…">
        Sil
      </SubmitButton>
      <FormAlert state={state} />
    </ActionForm>
  );
}
