"use client";

import { useActionState } from "react";
import { ActionForm, FormAlert, SubmitButton, inputClass, type ActionState } from "@/components/ui";
import { reviewSubmission } from "./actions";

// Onayla ya da gerekçeyle reddet (review_campus_submission). Hangi düğmeye basıldığı "decision" alanıyla gelir.
export function ReviewForm({ id }: { id: string }) {
  const [state, action, pending] = useActionState(reviewSubmission, {} as ActionState);
  return (
    <ActionForm action={action} state={state} pending={pending} className="flex flex-col gap-2">
      <input type="hidden" name="id" value={id} />
      <input name="note" maxLength={300} placeholder="Ret gerekçesi (reddederken zorunlu)" className={inputClass} />
      <div className="flex flex-wrap gap-2">
        <SubmitButton name="decision" value="approve" pendingText="Onaylanıyor…">
          Onayla
        </SubmitButton>
        <SubmitButton name="decision" value="reject" tone="danger" pendingText="Reddediliyor…">
          Reddet
        </SubmitButton>
      </div>
      <FormAlert state={state} />
    </ActionForm>
  );
}
