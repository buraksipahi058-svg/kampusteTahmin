"use client";

import { useActionState } from "react";
import { ActionForm, FormAlert, SubmitButton, inputClass, type ActionState } from "@/components/ui";
import { cancelDailyPrediction, settleDailyPrediction } from "./actions";

type Option = { id: string; label: string };

// Bir tahminin sonuç / iptal formları. Sonuç yalnızca kapanıştan sonra gösterilir;
// yasak bir işlem denenirse veritabanı reddeder.
export function PredictionActions({
  betId,
  options,
  canSettle,
}: {
  betId: string;
  options: Option[];
  canSettle: boolean;
}) {
  const [settleState, settleAction, settleActionPending] = useActionState(settleDailyPrediction, {} as ActionState);
  const [cancelState, cancelAction, cancelActionPending] = useActionState(cancelDailyPrediction, {} as ActionState);

  return (
    <div className="mt-3 flex flex-col gap-3 border-t border-zinc-200 pt-3 dark:border-zinc-800">
      {canSettle && (
        <ActionForm action={settleAction} state={settleState} pending={settleActionPending} className="flex flex-wrap items-center gap-2">
          <input type="hidden" name="bet_id" value={betId} />
          <select name="winning_option_id" required defaultValue="" className={inputClass}>
            <option value="" disabled>
              Sonuç…
            </option>
            {options.map((o) => (
              <option key={o.id} value={o.id}>
                {o.label}
              </option>
            ))}
          </select>
          <SubmitButton pendingText="Dağıtılıyor…">Sonucu gir ve dağıt</SubmitButton>
          <FormAlert state={settleState} />
        </ActionForm>
      )}
      <ActionForm action={cancelAction} state={cancelState} pending={cancelActionPending} className="flex flex-wrap items-center gap-2">
        <input type="hidden" name="bet_id" value={betId} />
        <input name="reason" placeholder="İptal gerekçesi (ör. soru yanlış yazıldı)" required minLength={3} className={`${inputClass} min-w-64`} />
        <SubmitButton tone="danger" pendingText="İptal ediliyor…">
          İptal et ve iade et
        </SubmitButton>
        <FormAlert state={cancelState} />
      </ActionForm>
    </div>
  );
}
