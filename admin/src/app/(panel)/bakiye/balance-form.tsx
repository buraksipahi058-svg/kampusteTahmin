"use client";

import { useActionState } from "react";
import { ActionForm, FormAlert, SubmitButton, inputClass, type ActionState } from "@/components/ui";
import { changeBalance } from "./actions";

type User = { id: string; label: string };

export function BalanceForm({ users }: { users: User[] }) {
  const [state, action, actionPending] = useActionState(changeBalance, {} as ActionState);
  return (
    <ActionForm action={action} state={state} pending={actionPending} className="flex max-w-xl flex-col gap-3">
      <label className="flex flex-col gap-1 text-sm">
        Kullanıcı
        <select name="user_id" required defaultValue="" className={inputClass}>
          <option value="" disabled>
            Seç…
          </option>
          {users.map((u) => (
            <option key={u.id} value={u.id}>
              {u.label}
            </option>
          ))}
        </select>
      </label>
      <div className="flex flex-wrap gap-4">
        <label className="flex flex-col gap-1 text-sm">
          İşlem
          <select name="mode" className={inputClass} defaultValue="grant">
            <option value="grant">Ver (yalnızca artı)</option>
            <option value="adjust">Düzelt (artı ya da eksi)</option>
          </select>
        </label>
        <label className="flex flex-col gap-1 text-sm">
          Para birimi
          <select name="currency" className={inputClass} defaultValue="SSP">
            <option value="SSP">SSP</option>
            <option value="SP">SP</option>
          </select>
        </label>
        <label className="flex flex-col gap-1 text-sm">
          Tutar
          <input name="amount" type="number" step={1} required className={`${inputClass} w-32`} />
        </label>
      </div>
      <label className="flex flex-col gap-1 text-sm">
        Gerekçe (ledger&apos;a yazılır)
        <input name="note" required minLength={3} maxLength={500} className={inputClass} placeholder="Bahar turnuvası birincilik ödülü" />
      </label>
      <FormAlert state={state} />
      <div>
        <SubmitButton pendingText="Yapılıyor…">Uygula</SubmitButton>
      </div>
    </ActionForm>
  );
}
