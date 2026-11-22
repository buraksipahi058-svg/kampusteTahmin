"use client";

import { createContext, startTransition, useContext, useEffect, useRef, type ReactNode } from "react";
import { useFormStatus } from "react-dom";

export type ActionState = { error?: string; message?: string };

// <form action={...}> React 19'da her gönderimden sonra formu boşaltır; hata alan formda girilenler
// kaybolur. ActionForm eylemi elle çağırır: hata olursa girilenler kalır, başarılı olunca form boşalır.
const PendingContext = createContext<boolean | null>(null);

export function ActionForm({
  action,
  state,
  pending,
  className,
  children,
}: {
  action: (formData: FormData) => void;
  state: ActionState;
  pending: boolean;
  className?: string;
  children: ReactNode;
}) {
  const ref = useRef<HTMLFormElement>(null);
  useEffect(() => {
    if (state.message && !state.error) ref.current?.reset();
  }, [state]);
  return (
    <form
      ref={ref}
      className={className}
      onSubmit={(event) => {
        event.preventDefault();
        // Basılan düğmenin name / value'su da gönderilsin (ör. itiraz kararı düğmeleri).
        const submitter = (event.nativeEvent as SubmitEvent).submitter;
        const formData = new FormData(event.currentTarget, submitter);
        startTransition(() => action(formData));
      }}
    >
      <PendingContext.Provider value={pending}>{children}</PendingContext.Provider>
    </form>
  );
}

export function SubmitButton({
  children,
  pendingText,
  tone = "primary",
}: {
  children: ReactNode;
  pendingText?: string;
  tone?: "primary" | "danger" | "neutral";
}) {
  const actionPending = useContext(PendingContext);
  const { pending: formPending } = useFormStatus();
  const pending = actionPending ?? formPending;
  const tones = {
    primary: "bg-zinc-900 text-white hover:bg-zinc-700 dark:bg-zinc-100 dark:text-zinc-900 dark:hover:bg-zinc-300",
    danger: "bg-red-700 text-white hover:bg-red-600",
    neutral: "border border-zinc-300 hover:bg-zinc-100 dark:border-zinc-700 dark:hover:bg-zinc-800",
  };
  return (
    <button
      type="submit"
      disabled={pending}
      className={`rounded-md px-3 py-1.5 text-sm font-medium disabled:opacity-50 ${tones[tone]}`}
    >
      {pending ? (pendingText ?? "Gönderiliyor…") : children}
    </button>
  );
}

export function FormAlert({ state }: { state: ActionState }) {
  if (state.error) return <p className="text-sm text-red-700 dark:text-red-400">{state.error}</p>;
  if (state.message) return <p className="text-sm text-green-700 dark:text-green-400">{state.message}</p>;
  return null;
}

export const inputClass =
  "rounded-md border border-zinc-300 bg-transparent px-2 py-1.5 text-sm dark:border-zinc-700";
