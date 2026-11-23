"use client";

import { useActionState } from "react";
import { ActionForm, FormAlert, SubmitButton, inputClass, type ActionState } from "@/components/ui";
import { cancelBet, lockBet, settleBet } from "./actions";

type Option = { id: string; label: string };

// Bir resmi bahsin kilitle / sonuçlandır / iptal formları. Hangisinin gösterileceğine sayfa karar verir;
// yasak bir işlem denenirse veritabanı reddeder.
export function BetActions({
  betId,
  options,
  canLock,
  canSettle,
}: {
  betId: string;
  options: Option[];
  canLock: boolean;
  canSettle: boolean;
}) {
  const [lockState, lockAction, lockActionPending] = useActionState(lockBet, {} as ActionState);
  const [settleState, settleAction, settleActionPending] = useActionState(settleBet, {} as ActionState);
  const [cancelState, cancelAction, cancelActionPending] = useActionState(cancelBet, {} as ActionState);

  return (
    <div className="mt-3 flex flex-col gap-3 border-t border-line pt-3">
      {canLock && (
        <ActionForm action={lockAction} state={lockState} pending={lockActionPending} className="flex flex-wrap items-center gap-2">
          <input type="hidden" name="bet_id" value={betId} />
          <SubmitButton tone="neutral" pendingText="Kilitleniyor…">
            Yatırımları şimdi kapat (kilitle)
          </SubmitButton>
          <FormAlert state={lockState} />
        </ActionForm>
      )}
      {canSettle && (
        <ActionForm action={settleAction} state={settleState} pending={settleActionPending} className="flex flex-wrap items-center gap-2">
          <input type="hidden" name="bet_id" value={betId} />
          <select name="winning_option_id" required defaultValue="" className={inputClass}>
            <option value="" disabled>
              Kazanan seçenek…
            </option>
            {options.map((o) => (
              <option key={o.id} value={o.id}>
                {o.label}
              </option>
            ))}
          </select>
          <SubmitButton pendingText="Sonuçlandırılıyor…">Sonuçlandır ve öde</SubmitButton>
          <FormAlert state={settleState} />
        </ActionForm>
      )}
      <ActionForm action={cancelAction} state={cancelState} pending={cancelActionPending} className="flex flex-wrap items-center gap-2">
        <input type="hidden" name="bet_id" value={betId} />
        <input name="reason" placeholder="İptal gerekçesi (ör. maç ertelendi)" required minLength={3} className={`${inputClass} min-w-64`} />
        <SubmitButton tone="danger" pendingText="İptal ediliyor…">
          İptal et ve iade et
        </SubmitButton>
        <FormAlert state={cancelState} />
      </ActionForm>
    </div>
  );
}
