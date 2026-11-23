"use client";

import { createContext, startTransition, useContext, useEffect, useRef, type ReactNode } from "react";
import { useFormStatus } from "react-dom";
import { toast } from "sonner";
import { buttonClass, inputClass as kitInputClass } from "./kit";

export type ActionState = { error?: string; message?: string };

// <form action={...}> React 19'da her gönderimden sonra formu boşaltır; hata alan formda girilenler
// kaybolur. ActionForm eylemi elle çağırır: hata olursa girilenler kalır, başarılı olunca form boşalır ve sonuç
// köşede kısa bildirimle (toast) gösterilir; hata formun içinde kalır (FormAlert).
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
    if (state.message && !state.error) {
      ref.current?.reset();
      toast.success(state.message);
    }
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
  name,
  value,
}: {
  children: ReactNode;
  pendingText?: string;
  tone?: "primary" | "danger" | "neutral";
  // Birden çok gönderme düğmesinde hangisine basıldığı (ActionForm submitter'ı gönderir).
  name?: string;
  value?: string;
}) {
  const actionPending = useContext(PendingContext);
  const { pending: formPending } = useFormStatus();
  const pending = actionPending ?? formPending;
  return (
    <button
      type="submit"
      name={name}
      value={value}
      disabled={pending}
      className={buttonClass(tone === "neutral" ? "secondary" : tone)}
    >
      {pending ? (pendingText ?? "Gönderiliyor…") : children}
    </button>
  );
}

/** Formun hatası formun içinde; başarı mesajı köşede bildirim olarak çıkar (ActionForm), burada da kısa kalır. */
export function FormAlert({ state }: { state: ActionState }) {
  if (state.error) return <p className="text-sm text-danger">{state.error}</p>;
  if (state.message) return <p className="text-sm text-success">{state.message}</p>;
  return null;
}

export const inputClass = kitInputClass;
