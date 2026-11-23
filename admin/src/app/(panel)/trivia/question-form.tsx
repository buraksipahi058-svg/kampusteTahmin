"use client";

import { useActionState, useState } from "react";
import { ActionForm, FormAlert, SubmitButton, inputClass, type ActionState } from "@/components/ui";
import { saveQuestion, toggleQuestion } from "./actions";
import { buttonClass } from "@/components/kit";

type School = { id: string; name: string };
export type Question = {
  id: string;
  school_id: string | null;
  question: string;
  options: string[];
  correct_index: number;
  category: string | null;
  active: boolean;
};

export function QuestionForm({
  schools,
  canGlobal,
  initial,
}: {
  schools: School[];
  canGlobal: boolean;
  initial?: Question;
}) {
  const [state, action, actionPending] = useActionState(saveQuestion, {} as ActionState);
  const [count, setCount] = useState(initial?.options.length ?? 4);

  return (
    <ActionForm action={action} state={state} pending={actionPending} className="flex max-w-xl flex-col gap-3 rounded-xl border border-line bg-panel/90 p-4">
      <h2 className="font-medium">{initial ? "Soruyu düzenle" : "Yeni soru"}</h2>
      {initial && <input type="hidden" name="id" value={initial.id} />}
      {initial && <input type="hidden" name="active" value={initial.active ? "on" : ""} />}
      <label className="flex flex-col gap-1 text-sm">
        Kapsam
        <select
          name="school_id"
          className={inputClass}
          defaultValue={initial ? (initial.school_id ?? "") : canGlobal ? "" : schools[0]?.id}
        >
          {canGlobal && <option value="">Tüm okullar (genel)</option>}
          {schools.map((s) => (
            <option key={s.id} value={s.id}>
              {s.name}
            </option>
          ))}
        </select>
      </label>
      <label className="flex flex-col gap-1 text-sm">
        Soru
        <input name="question" required minLength={5} maxLength={300} defaultValue={initial?.question} className={inputClass} />
      </label>
      <fieldset className="flex flex-col gap-2 text-sm">
        <legend className="mb-1">Şıklar (doğru olanı işaretle)</legend>
        {Array.from({ length: count }, (_, i) => (
          <div key={i} className="flex items-center gap-2">
            <input
              type="radio"
              name="correct"
              value={i}
              required
              defaultChecked={initial ? i === initial.correct_index : false}
              aria-label={`${i + 1}. şık doğru`}
            />
            <input
              name="option"
              required
              maxLength={100}
              defaultValue={initial?.options[i]}
              placeholder={`${i + 1}. şık`}
              className={`${inputClass} flex-1`}
            />
          </div>
        ))}
        <div className="flex gap-3">
          {count < 4 && (
            <button type="button" className={buttonClass("secondary", "sm")} onClick={() => setCount(count + 1)}>
              Şık ekle
            </button>
          )}
          {count > 2 && (
            <button type="button" className={buttonClass("ghost", "sm")} onClick={() => setCount(count - 1)}>
              Son şıkkı kaldır
            </button>
          )}
        </div>
      </fieldset>
      <label className="flex flex-col gap-1 text-sm">
        Kategori (isteğe bağlı)
        <input
          name="category"
          maxLength={50}
          defaultValue={initial?.category ?? ""}
          className={inputClass}
          placeholder="Kampüs, Spor, Tarih…"
        />
      </label>
      <FormAlert state={state} />
      <div>
        <SubmitButton pendingText="Kaydediliyor…">{initial ? "Kaydet" : "Soruyu ekle"}</SubmitButton>
      </div>
    </ActionForm>
  );
}

export function ToggleQuestion({ id, active }: { id: string; active: boolean }) {
  const [state, action, actionPending] = useActionState(toggleQuestion, {} as ActionState);
  return (
    <ActionForm action={action} state={state} pending={actionPending} className="flex items-center gap-2">
      <input type="hidden" name="id" value={id} />
      <SubmitButton tone="neutral" pendingText="…">
        {active ? "Kapat" : "Aç"}
      </SubmitButton>
      <FormAlert state={state} />
    </ActionForm>
  );
}
