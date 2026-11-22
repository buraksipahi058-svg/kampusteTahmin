// Veritabanından gelen hata kodlarını Türkçe mesaja çevirir. Kodların listesi:
// docs/harita/veritabani.md "Hata kodları" (mobildeki eşlemeyle aynı anlamlar).
const messages: Record<string, string> = {
  KB001: "Bakiye yetersiz.",
  KB002: "Bu işlem için okul maili doğrulanmış olmalı.",
  KB003: "Bahis açık değil.",
  KB004: "Bu bahse zaten yatırım yapılmış.",
  KB005: "Bahis henüz yatırıma açık; önce kilitlenmeli ya da kapanış zamanı geçmeli.",
  KB006: "Bahis zaten sonuçlandı ya da iptal edildi.",
  KB007: "Mail adresi okulun öğrenci alan adında değil.",
  KB008: "Bu okul maili başka bir hesaba bağlı.",
  KB009: "Okul maili zaten doğrulanmış.",
  KB010: "Çok sık kod istendi.",
  KB011: "Kodun süresi doldu.",
  KB012: "Deneme hakkı bitti.",
  KB013: "Mail servisi yapılandırılmamış.",
  KB014: "Hakemlik hakkı ihtar sınırı yüzünden kısıtlı.",
  KB015: "Bu bahsin sonucu zaten girildi.",
  KB016: "Sonuca şu an itiraz edilemez.",
  KB017: "Çözülecek açık itiraz yok.",
  KB018: "Düello katılıma ya da oynamaya açık değil.",
  KB019: "Görev henüz tamamlanmadı.",
  KB020: "Bu görevin ödülü bu dönem zaten alındı.",
  KB021: "Ürün şu an satışta değil.",
  KB022: "Bu ürün zaten alınmış.",
  "42501": "Bu işlem için yetkin yok.",
  "23514": "Girilen bilgilerden biri geçersiz.",
  "23505": "Bu kayıt zaten var.",
  "23503": "Bağlı kayıt bulunamadı.",
  P0002: "Kayıt bulunamadı.",
  "55000": "Bu kayıt değiştirilemez.",
  "22003": "İzin verilen üst sınır aşıldı.",
};

export function dbErrorMessage(error: { code?: string; message?: string } | null | undefined): string {
  if (!error) return "Bilinmeyen hata.";
  const known = error.code ? messages[error.code] : undefined;
  // Veritabanı fonksiyonlarımız Türkçe ve kullanıcıya gösterilebilir mesajlar üretir; KB/standart
  // kodlarda o ayrıntılı mesaj tercih edilir, bilinmeyen kodda genel mesaj gösterilir.
  if (known && error.message && /[çğıöşüÇĞİÖŞÜ]|^[A-ZÇĞİÖŞÜ]/.test(error.message)) return error.message;
  return known ?? "Bir şeyler ters gitti. Tekrar dene.";
}
