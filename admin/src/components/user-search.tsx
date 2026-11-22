import { inputClass } from "./ui";

// Ada göre kullanıcı arama (GET formu; sonuç sayfanın searchParams'ından okunur).
export function UserSearch({ q }: { q: string }) {
  return (
    <form className="flex gap-2">
      <input name="q" defaultValue={q} placeholder="Ad ya da soyad ara" className={`${inputClass} w-64`} />
      <button className="rounded-md border border-zinc-300 px-3 py-1.5 text-sm dark:border-zinc-700">Ara</button>
    </form>
  );
}

// PostgREST `or` filtresinde anlamı olan karakterler atılır.
export function cleanQuery(value: string | string[] | undefined): string {
  return String(Array.isArray(value) ? value[0] : (value ?? ""))
    .replace(/[,()%*\\:."]/g, " ")
    .trim()
    .slice(0, 50);
}
