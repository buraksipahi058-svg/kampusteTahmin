"use client";

import { useActionState } from "react";
import { ActionForm, FormAlert, SubmitButton, inputClass, type ActionState } from "@/components/ui";
import { resetStrikes, setBan } from "./actions";

export function UserActions({
  userId,
  banned,
  strikes,
  canBan,
  canForgive,
}: {
  userId: string;
  banned: boolean;
  strikes: number;
  canBan: boolean;
  canForgive: boolean;
}) {
  const [banState, banAction, banPending] = useActionState(setBan, {} as ActionState);
  const [strikeState, strikeAction, strikePending] = useActionState(resetStrikes, {} as ActionState);

  return (
    <div className="flex flex-col gap-2">
      {canBan && (
        <ActionForm action={banAction} state={banState} pending={banPending} className="flex flex-wrap items-center gap-2">
          <input type="hidden" name="user_id" value={userId} />
          {banned ? (
            <SubmitButton tone="neutral" pendingText="Kaldırılıyor…">
              Yasağı kaldır
            </SubmitButton>
          ) : (
            <>
              <input type="hidden" name="banned" value="on" />
              <input name="reason" required minLength={3} maxLength={300} placeholder="Yasak gerekçesi" className={`${inputClass} w-56`} />
              <SubmitButton tone="danger" pendingText="Yasaklanıyor…">
                Yasakla
              </SubmitButton>
            </>
          )}
          <FormAlert state={banState} />
        </ActionForm>
      )}
      {canForgive && strikes > 0 && (
        <ActionForm action={strikeAction} state={strikeState} pending={strikePending} className="flex flex-wrap items-center gap-2">
          <input type="hidden" name="user_id" value={userId} />
          <input name="note" required minLength={3} maxLength={300} placeholder="Sıfırlama gerekçesi" className={`${inputClass} w-56`} />
          <SubmitButton tone="neutral" pendingText="Sıfırlanıyor…">
            İhtarları sıfırla ({strikes})
          </SubmitButton>
          <FormAlert state={strikeState} />
        </ActionForm>
      )}
    </div>
  );
}
