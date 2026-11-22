"use client";

import { useActionState } from "react";
import { ActionForm, FormAlert, SubmitButton, inputClass, type ActionState } from "@/components/ui";
import { cancelSocialBet } from "./actions";

export function CancelSocialBet({ betId }: { betId: string }) {
  const [state, action, pending] = useActionState(cancelSocialBet, {} as ActionState);
  return (
    <ActionForm action={action} state={state} pending={pending} className="flex flex-wrap items-center gap-2">
      <input type="hidden" name="bet_id" value={betId} />
      <input name="reason" required minLength={3} maxLength={300} placeholder="İptal gerekçesi" className={`${inputClass} w-56`} />
      <SubmitButton tone="danger" pendingText="İptal ediliyor…">
        İptal et ve iade et
      </SubmitButton>
      <FormAlert state={state} />
    </ActionForm>
  );
}
