"use client";

import { useActionState } from "react";
import { FormAlert, SubmitButton, inputClass, type ActionState } from "@/components/ui";
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
  const [grantState, grantAction] = useActionState(grantPermission, {} as ActionState);
  const [revokeState, revokeAction] = useActionState(revokePermission, {} as ActionState);
  const missing = (Object.keys(labels) as PermissionKey[]).filter((k) => !held.includes(k));

  return (
    <div className="flex flex-col gap-2">
      <div className="flex flex-wrap gap-2">
        {held.length === 0 && <span className="text-sm text-zinc-500">İzni yok</span>}
        {held.map((key) => (
          <form key={key} action={revokeAction} className="flex items-center gap-1 rounded-full border border-zinc-300 px-2 py-0.5 text-xs dark:border-zinc-700">
            <input type="hidden" name="user_id" value={userId} />
            <input type="hidden" name="school_id" value={schoolId} />
            <input type="hidden" name="key" value={key} />
            {labels[key]}
            <button type="submit" aria-label={`${labels[key]} iznini geri al`} className="ml-1 text-red-700">
              ×
            </button>
          </form>
        ))}
      </div>
      {missing.length > 0 && (
        <form action={grantAction} className="flex flex-wrap items-center gap-2">
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
        </form>
      )}
      <FormAlert state={grantState.error || grantState.message ? grantState : revokeState} />
    </div>
  );
}
