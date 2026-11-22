const dateTime = new Intl.DateTimeFormat("tr-TR", {
  timeZone: "Europe/Istanbul",
  dateStyle: "medium",
  timeStyle: "short",
});
const number = new Intl.NumberFormat("tr-TR");

export const formatDateTime = (iso: string) => dateTime.format(new Date(iso));
// "2026-11-16" gibi tarih → "16 Kas 2026".
export const formatDate = (date: string) =>
  new Intl.DateTimeFormat("tr-TR", { dateStyle: "medium", timeZone: "UTC" }).format(new Date(`${date}T00:00:00Z`));
export const formatAmount = (value: number) => number.format(value);
export const formatOdds = (value: number | null) =>
  value == null ? "–" : value.toLocaleString("tr-TR", { minimumFractionDigits: 2, maximumFractionDigits: 2 });

// Sayfa her istekte sunucuda çizildiği için "şu an" isteğin anıdır.
export const isPast = (iso: string) => Date.parse(iso) <= Date.now();

// <input type="datetime-local"> değeri İstanbul saati kabul edilir (Türkiye yıl boyu UTC+3).
export const istanbulLocalToIso = (local: string) => new Date(`${local}:00+03:00`).toISOString();

// ISO zaman → <input type="datetime-local"> değeri (İstanbul saati), düzenleme formlarının varsayılanı için.
export const isoToIstanbulLocal = (iso: string | null) =>
  iso == null ? "" : new Date(Date.parse(iso) + 3 * 60 * 60 * 1000).toISOString().slice(0, 16);
