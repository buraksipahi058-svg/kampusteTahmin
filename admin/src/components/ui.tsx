"use client";

import type { ReactNode } from "react";
import { useFormStatus } from "react-dom";

export type ActionState = { error?: string; message?: string };

export function SubmitButton({
  children,
  pendingText,
  tone = "primary",
}: {
  children: ReactNode;
  pendingText?: string;
  tone?: "primary" | "danger" | "neutral";
}) {
  const { pending } = useFormStatus();
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
