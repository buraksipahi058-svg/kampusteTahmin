# KampüsBet — Proje Haritası

Amaç: projeyi **en az bağlam harcayarak** anlamak. Bu dosyayı oku, sonra yalnızca görevin
gerektirdiği bölgeleri aç. Kod dosyalarını baştan sona okuma; bölge dosyası nereye bakacağını söyler.

## Şu an

- **Commit:** yalnızca kullanıcı onay verince, yalnızca yerel (push yok). Adım 7-9 `f45f3dc`'de; Adım 10 + XP / seviye `0ca9789`'da, Adım 11 `2fa4c08`'de; Adım 12 çalışma ağacında, commit edilmedi.
- **Son tamamlanan:** baştan sona kalite kontrolü ve güvenlik çift kontrolü (Adım 12 üstüne): iki bağımsız kod incelemesi, canlı API'ye anonim deneme (37 RPC, 24 tablo), emülatörde tüm ekranlar. Düzeltilen: eşzamanlı görev ödüllerinde veritabanı kilitlenmesi (testle yakalandı), silinen hesabın anahtarı geçerliyken yeniden doğrulanması, düello başlığında silinen ad, görev yöneticisinin kendine ödül basması, admin çıkışının telefonu da kapatması, admin formlarının hata alınca boşalması, bahis sonrası görev / XP / istatistik yenilenmemesi, okul listesi sırası, kazanç metinleri, güvenlik başlıkları, Android yedek ayarı (ayrıntı: [guvenlik](harita/guvenlik.md) "Kalite kontrolü"). 586 pgTAP, eşzamanlılık para 8/8 + bahis 6/6, 46 Flutter testi, admin lint / tip / build temiz. Adım 12: yayına hazırlık ([yayin](harita/yayin.md)); Adım 11: güvenlik, hesap silme, KVKK.
- **Bulutta deneme verisi:** giriş yapamayan "Test Yetkili" profili (`e2e00000-...0001`), sonuçlanmış resmi ve sosyal deneme bahisleri, bir trivia düellosu, bir günün tahmini; kullanıcının test hesabı `deneme@ogr.ornek.edu.tr` ile doğrulanmış (820 SP, 20 XP, "Mor isim" kuşanılı). Seed'de 5 genel görev, 8 genel ürün.
- **Sıradaki:** kullanıcının canlıya geçiş adımları ([yayin](harita/yayin.md) "Canlıya geçiş sırası"); uygulama tarafında kalanlar [acik-isler](harita/acik-isler.md)'de (bildirimler, ikon, admin panelinin girişle denenmesi, eksik özellikler).
- **Açık işler** (denenmemiş, eksik, çözülmemiş, kullanıcıdan beklenen): [harita/acik-isler.md](harita/acik-isler.md).

| # | Adım | Durum | Commit |
|---|---|---|---|
| 0 | Ortam + iskelet | Bitti | `72b41cf` |
| 1 | Kümeler, profiller, yetkiler, RLS | Bitti | `af1c23a` |
| 2 | Para çekirdeği | Bitti | `1ff2cfb` |
| 3 | Bahis çekirdeği | Bitti | `ecc3be0` |
| 4 | Mobil temel | Bitti | `820d315` |
| 5 | Okul maili doğrulama | Bitti | `eea1448` |
| 6 | Resmi SSP bahisler + admin paneli | Bitti | `eea1448` |
| 7 | Sosyal havuz (hakem, itiraz) | Bitti | `f45f3dc` |
| 8 | Mini oyunlar (trivia düellosu, günün tahmini) | Bitti | `f45f3dc` |
| 9 | Görevler + market | Bitti | `f45f3dc` |
| 10 | Liderlik + istatistik, XP / seviye | Bitti | `0ca9789` |
| 11 | Güvenlik denetimi, hesap silme, KVKK | Bitti | `2fa4c08` |
| 12 | Yayına hazırlık (linkler, şifre, Android imza, mağaza sayfaları) + kalite kontrolü | Bitti (commit yok) | |

## Görev → ne okunur

| Görev | Oku | Okuma |
|---|---|---|
| Mobil ekran / akış (Adım 4) | [mobil](harita/mobil.md) + gerekirse ilgili konu bölgesi (kimlik / para / bahis) | migration'lar, testler |
| Admin ekranı (Adım 6) | [admin](harita/admin.md) + ilgili konu bölgesi | migration'lar |
| Yeni SQL tablo / fonksiyon / RLS | [veritabani](harita/veritabani.md) + konu bölgesi + [testler](harita/testler.md) | eski test dosyalarının tamamı |
| Okul, profil, yetki, okul maili (Adım 5) | [kimlik](harita/kimlik.md) | |
| Bakiye, ödül, market, görev (Adım 9), XP / seviye | [para](harita/para.md) | |
| Resmi / sosyal / mini oyun bahisleri (Adım 6-8) | [bahis](harita/bahis.md) | |
| Liderlik, kişisel istatistik, admin okul özeti (Adım 10) | [liderlik](harita/liderlik.md) | |
| Güvenlik kuralları, hesap silme, KVKK metni (Adım 11) | [guvenlik](harita/guvenlik.md) | |
| Canlıya geçiş, Android yayın derlemesi, e-posta linkleri, mağaza (Adım 12) | [yayin](harita/yayin.md) | |
| Komut çalıştırma, araç, emülatör, CLI hatası | [ortam](harita/ortam.md) | |
| Test yazma / çalıştırma | [testler](harita/testler.md) | |
| Denenmemiş / eksik / çözülmemiş ne var, kullanıcıdan ne bekleniyor | [acik-isler](harita/acik-isler.md) | |
| Bir kararın gerekçesi | `docs/KARARLAR.md`'de ilgili satırı ara | dosyanın tamamı |
| Ürün vizyonu (ekran haritası, oyunlaştırma) | `docs/MIMARI.md`'nin ilgili bölümü | dosyanın tamamı |

Bölge dosyaları 30-60 satırdır; bir görev genelde 1-3 bölge ister.

## Haritayı güncel tutmak

Bir adım bitince yalnızca: bu dosyadaki "Şu an" ve adım tablosu, değişen bölgenin dosyası.
Yeni karar `KARARLAR.md`'ye tek satır. Geçmiş kaydı tutulmaz; git log yeter.
