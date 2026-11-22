"use client";

import { useActionState } from "react";
import { ActionForm, FormAlert, SubmitButton, inputClass, type ActionState } from "@/components/ui";
import { updateOdds } from "./actions";

type Option = { id: string; label: string; odds: number | null };

// Açık sabit oranlı bahiste oran değiştirme (resmi_bahis_ac). Yapılmış yatırımlar kendi oranıyla kalır.
export function OddsForm({ betId, options }: { betId: string; options: Option[] }) {
  const [state, action, pending] = useActionState(updateOdds, {} as ActionState);
  return (
    <ActionForm action={action} state={state} pending={pending} className="mt-3 flex flex-wrap items-end gap-2 border-t border-zinc-200 pt-3 dark:border-zinc-800">
      <input type="hidden" name="bet_id" value={betId} />
      {options.map((o) => (
        <label key={o.id} className="flex flex-col gap-1 text-sm">
          {o.label}
          <input
            name="odds"
            inputMode="decimal"
            required
            defaultValue={o.odds == null ? "" : o.odds.toFixed(2).replace(".", ",")}
            className={`${inputClass} w-20`}
          />
        </label>
      ))}
      <SubmitButton tone="neutral" pendingText="Güncelleniyor…">
        Oranları güncelle
      </SubmitButton>
      <FormAlert state={state} />
      <p className="w-full text-xs text-zinc-500">Yapılmış yatırımlar yatırdıkları andaki oranla ödenir.</p>
    </ActionForm>
  );
}
