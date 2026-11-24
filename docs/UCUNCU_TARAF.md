# Üçüncü taraf içerik

## Türkçe kelime sözlüğü (Kampüs kelimesi)

`supabase/migrations/20261124074450_kelime_sozlugu.sql` içindeki kelime listesi, zemberek-nlp projesinin
`morphology/src/main/resources/tr/master-dictionary.dict` dosyasından türetilmiştir:
<https://github.com/ahmetaa/zemberek-nlp>

Değişiklik: yalnızca 4–8 harfli kök kelimeler alındı; özel adlar, kısaltmalar, noktalama ve ek bilgiler çıkarıldı;
şapkalı harfler düzleştirildi; kelimeler Türkçe büyük harfe çevrildi (`supabase/sozluk/sozluk_migration.py`).

Lisans metni (kaynaktaki LICENSE dosyası):

```
Copyright 2018 Ahmet A. Akın, Mehmet D. Akın

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
