"use client";

import { useActionState, useState } from "react";
import { ActionForm, FormAlert, SubmitButton, inputClass, type ActionState } from "@/components/ui";
import { resolveDispute } from "./actions";

type Option = { id: string; label: string };

export function DisputeForm({ betId, options, proposedId }: { betId: string; options: Option[]; proposedId: string }) {
  const [state, action, actionPending] = useActionState(resolveDispute, {} as ActionState);
  const [decision, setDecision] = useState("confirmed");
  const others = options.filter((o) => o.id !== proposedId);

  return (
    <ActionForm action={action} state={state} pending={actionPending} className="mt-3 flex flex-col gap-2 border-t border-line pt-3">
      <input type="hidden" name="bet_id" value={betId} />
      <div className="flex flex-wrap gap-4 text-sm">
        {[
          ["confirmed", "Hakemin sonucunu onayla"],
          ["changed", "Sonucu değiştir (hakeme ihtar)"],
          ["cancelled", "İptal et ve herkese iade et (hakeme ihtar)"],
        ].map(([value, label]) => (
          <label key={value} className="flex items-center gap-1">
            <input
              type="radio"
              name="decision"
              value={value}
              checked={decision === value}
              onChange={() => setDecision(value)}
            />
            {label}
          </label>
        ))}
      </div>
      {decision === "changed" && (
        <select name="option_id" required defaultValue="" className={`${inputClass} self-start`}>
          <option value="" disabled>
            Doğru sonuç…
          </option>
          {others.map((o) => (
            <option key={o.id} value={o.id}>
              {o.label}
            </option>
          ))}
        </select>
      )}
      <input name="note" required minLength={3} maxLength={500} placeholder="Karar gerekçesi" className={inputClass} />
      <div className="flex items-center gap-3">
        <SubmitButton pendingText="Uygulanıyor…">Kararı uygula</SubmitButton>
        <FormAlert state={state} />
      </div>
    </ActionForm>
  );
}
