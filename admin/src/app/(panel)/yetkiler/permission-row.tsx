"use client";

import { useActionState, useState } from "react";
import { ActionForm, FormAlert, SubmitButton, inputClass, type ActionState } from "@/components/ui";
import type { PermissionKey } from "@/lib/auth";
import { grantPermission, revokePermission } from "./actions";

export function PermissionRow({
  userId,
  schoolId,
  held,
  labels,
}: {
  userId: string;
  schoolId: string;
  held: PermissionKey[];
  labels: Record<PermissionKey, string>;
}) {
  const [grantState, grantAction, grantActionPending] = useActionState(grantPermission, {} as ActionState);
  const [revokeState, revokeAction, revokeActionPending] = useActionState(revokePermission, {} as ActionState);
  const [last, setLast] = useState<"grant" | "revoke">("grant");
  const missing = (Object.keys(labels) as PermissionKey[]).filter((k) => !held.includes(k));

  return (
    <div className="flex flex-col gap-2">
      <div className="flex flex-wrap gap-2">
        {held.length === 0 && <span className="text-sm text-muted">İzni yok</span>}
        {held.map((key) => (
          <ActionForm key={key} action={(formData) => {
            setLast("revoke");
            revokeAction(formData);
          }} state={revokeState} pending={revokeActionPending} className="flex items-center gap-1 rounded-full border border-line-strong px-2 py-0.5 text-xs">
            <input type="hidden" name="user_id" value={userId} />
            <input type="hidden" name="school_id" value={schoolId} />
            <input type="hidden" name="key" value={key} />
            {labels[key]}
            <button type="submit" aria-label={`${labels[key]} iznini geri al`} className="ml-1 text-danger">
              ×
            </button>
          </ActionForm>
        ))}
      </div>
      {missing.length > 0 && (
        <ActionForm action={(formData) => {
            setLast("grant");
            grantAction(formData);
          }} state={grantState} pending={grantActionPending} className="flex flex-wrap items-center gap-2">
          <input type="hidden" name="user_id" value={userId} />
          <input type="hidden" name="school_id" value={schoolId} />
          <select name="key" required defaultValue="" className={inputClass}>
            <option value="" disabled>
              İzin seç…
            </option>
            {missing.map((k) => (
              <option key={k} value={k}>
                {labels[k]}
              </option>
            ))}
          </select>
          <SubmitButton tone="neutral" pendingText="Veriliyor…">
            İzin ver
          </SubmitButton>
        </ActionForm>
      )}
      <FormAlert state={last === "grant" ? grantState : revokeState} />
    </div>
  );
}
