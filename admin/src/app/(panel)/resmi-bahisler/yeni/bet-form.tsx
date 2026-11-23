"use client";

import { useActionState, useState } from "react";
import { ActionForm, FormAlert, SubmitButton, inputClass, type ActionState } from "@/components/ui";
import { createOfficialBet } from "../actions";
import { buttonClass } from "@/components/kit";

type School = { id: string; name: string };

export function OfficialBetForm({ schools }: { schools: School[] }) {
  const [state, action, actionPending] = useActionState(createOfficialBet, {} as ActionState);
  const [rows, setRows] = useState([0, 1]);
  const [nextKey, setNextKey] = useState(2);

  return (
    <ActionForm action={action} state={state} pending={actionPending} className="flex max-w-xl flex-col gap-4">
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
        Başlık
        <input name="title" required minLength={3} maxLength={140} className={inputClass} placeholder="Bahar turnuvası finalini kim kazanır?" />
      </label>
      <label className="flex flex-col gap-1 text-sm">
        Açıklama (isteğe bağlı)
        <textarea name="description" maxLength={2000} rows={2} className={inputClass} />
      </label>

      <fieldset className="flex flex-col gap-2">
        <legend className="mb-1 text-sm">Seçenekler ve oranlar (2–10 seçenek, oran 1,01–20,00)</legend>
        {rows.map((key, i) => (
          <div key={key} className="flex items-center gap-2">
            <input name="label" required maxLength={100} placeholder={`Seçenek ${i + 1}`} className={`${inputClass} flex-1`} />
            <input name="odds" required inputMode="decimal" placeholder="1,85" className={`${inputClass} w-24`} />
            {rows.length > 2 && (
              <button type="button" onClick={() => setRows(rows.filter((r) => r !== key))} className={buttonClass("ghost", "sm")}>
                Kaldır
              </button>
            )}
          </div>
        ))}
        {rows.length < 10 && (
          <button
            type="button"
            onClick={() => {
              setRows([...rows, nextKey]);
              setNextKey(nextKey + 1);
            }}
            className={`self-start ${buttonClass("secondary", "sm")}`}
          >
            Seçenek ekle
          </button>
        )}
      </fieldset>

      <div className="flex flex-wrap gap-4">
        <label className="flex flex-col gap-1 text-sm">
          Kapanış (İstanbul saati)
          <input name="locks_at" type="datetime-local" required className={inputClass} />
        </label>
        <label className="flex flex-col gap-1 text-sm">
          Kişi başı en fazla SSP (isteğe bağlı)
          <input name="max_stake" type="number" min={1} className={inputClass} />
        </label>
      </div>

      <FormAlert state={state} />
      <div>
        <SubmitButton pendingText="Açılıyor…">Resmi bahsi aç</SubmitButton>
      </div>
    </ActionForm>
  );
}
