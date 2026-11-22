# KampüsBet — Proje Haritası

Amaç: projeyi **en az bağlam harcayarak** anlamak. Bu dosyayı oku, sonra yalnızca görevin
gerektirdiği bölgeleri aç. Kod dosyalarını baştan sona okuma; bölge dosyası nereye bakacağını söyler.

## Şu an

- **Commit yok:** kullanıcı söyleyene kadar yerel commit de atılmıyor (KARARLAR "Repo"). Adım 5 ve 6 çalışma ağacında.
- **Son tamamlanan:** Adım 6 (resmi SSP bahisler, sabit oran + admin paneli). 229 pgTAP, 22 Flutter testi, bahis eşzamanlılığı 5/5; admin lint/tip/build temiz. Emülatörde: resmi bahse 100 SSP → sonuçlandırma → "Kazandın: +180 SSP". Admin panelinde giriş sonrası ekranlar tarayıcıda denenmedi (kullanıcının girişi gerekiyor).
- **Bulutta deneme verisi:** giriş yapamayan "Test Yetkili" profili (`e2e00000-...0001`, Örnek Üniversitesi, resmi bahis izinleri), onun açtığı sonuçlanmış "Bahar turnuvası finali (deneme)" bahsi; kullanıcının test hesabı `deneme@ogr.ornek.edu.tr` ile doğrulanmış ve 580 SSP'li.
- **Sıradaki:** Adım 7 — sosyal havuz (hakem, itiraz penceresi, moderatör kuyruğu). Ayrıntı [bahis](harita/bahis.md).
- **Kullanıcıdan beklenenler:** admin panelini denemek için hesabının yetkili/süperadmin yapılması; gerçek mail sağlayıcısı (öneri Brevo, [kimlik](harita/kimlik.md)); gerçek okulun adı ve öğrenci mail alan adı; `KARARLAR.md` açık öneriler 4–8; Adım 9'da ekonomi rakamları.

| # | Adım | Durum | Commit |
|---|---|---|---|
| 0 | Ortam + iskelet | Bitti | `72b41cf` |
| 1 | Kümeler, profiller, yetkiler, RLS | Bitti | `af1c23a` |
| 2 | Para çekirdeği | Bitti | `1ff2cfb` |
| 3 | Bahis çekirdeği | Bitti | `ecc3be0` |
| 4 | Mobil temel | Bitti | `820d315` |
| 5 | Okul maili doğrulama | Bitti (commit yok) | |
| 6 | Resmi SSP bahisler + admin paneli | Bitti (commit yok) | |
| 7 | Sosyal havuz (hakem, itiraz) | Sırada | |
| 8 | Mini oyunlar | | |
| 9 | Görevler + market | | |
| 10 | Liderlik + istatistik | | |
| 11 | Güvenlik denetimi, hesap silme, KVKK | | |

## Görev → ne okunur

| Görev | Oku | Okuma |
|---|---|---|
| Mobil ekran / akış (Adım 4) | [mobil](harita/mobil.md) + gerekirse ilgili konu bölgesi (kimlik / para / bahis) | migration'lar, testler |
| Admin ekranı (Adım 6) | [admin](harita/admin.md) + ilgili konu bölgesi | migration'lar |
| Yeni SQL tablo / fonksiyon / RLS | [veritabani](harita/veritabani.md) + konu bölgesi + [testler](harita/testler.md) | eski test dosyalarının tamamı |
| Okul, profil, yetki, okul maili (Adım 5) | [kimlik](harita/kimlik.md) | |
| Bakiye, ödül, market, görev (Adım 9) | [para](harita/para.md) | |
| Resmi / sosyal / mini oyun bahisleri (Adım 6-8) | [bahis](harita/bahis.md) | |
| Komut çalıştırma, araç, emülatör, CLI hatası | [ortam](harita/ortam.md) | |
| Test yazma / çalıştırma | [testler](harita/testler.md) | |
| Bir kararın gerekçesi | `docs/KARARLAR.md`'de ilgili satırı ara | dosyanın tamamı |
| Ürün vizyonu (ekran haritası, oyunlaştırma) | `docs/MIMARI.md`'nin ilgili bölümü | dosyanın tamamı |

Bölge dosyaları 30-60 satırdır; bir görev genelde 1-3 bölge ister.

## Haritayı güncel tutmak

Bir adım bitince yalnızca: bu dosyadaki "Şu an" ve adım tablosu, değişen bölgenin dosyası.
Yeni karar `KARARLAR.md`'ye tek satır. Geçmiş kaydı tutulmaz; git log yeter.
