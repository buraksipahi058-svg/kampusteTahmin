"use client";

import { useActionState } from "react";
import { ActionForm, FormAlert, SubmitButton, inputClass, type ActionState } from "@/components/ui";
import { login } from "./actions";

export function LoginForm() {
  const [state, action, actionPending] = useActionState(login, {} as ActionState);
  return (
    <ActionForm action={action} state={state} pending={actionPending} className="flex flex-col gap-3">
      <label className="flex flex-col gap-1 text-sm">
        E-posta
        <input name="email" type="email" autoComplete="email" required className={inputClass} />
      </label>
      <label className="flex flex-col gap-1 text-sm">
        Şifre
        <input name="password" type="password" autoComplete="current-password" required className={inputClass} />
      </label>
      <FormAlert state={state} />
      <SubmitButton pendingText="Giriş yapılıyor…">Giriş yap</SubmitButton>
    </ActionForm>
  );
}
