-- Geliştirme verisi: MVP tek okulla başlar (MIMARI §2.5). Gerçek okul belli olunca ad ve alan adı güncellenir.
-- Tekrar çalıştırılabilir.

insert into public.clusters (id, name, type)
values ('10000000-0000-4000-8000-000000000001', 'Örnek Üniversitesi', 'school')
on conflict (id) do nothing;

insert into public.school_email_domains (domain, school_id)
values ('ogr.ornek.edu.tr', '10000000-0000-4000-8000-000000000001')
on conflict (domain) do nothing;

-- Trivia düellosu için genel kültür soruları (tüm okullar). Okula özel sorular admin panelinden eklenir.
insert into public.trivia_questions (id, school_id, question, options, correct_index, category) values
  ('20000000-0000-4000-8000-000000000001', null, 'Türkiye''nin başkenti neresidir?', array['İstanbul', 'Ankara', 'İzmir', 'Bursa'], 1, 'Genel kültür'),
  ('20000000-0000-4000-8000-000000000002', null, 'Bir yılda kaç ay vardır?', array['10', '11', '12', '13'], 2, 'Genel kültür'),
  ('20000000-0000-4000-8000-000000000003', null, 'Suyun kimyasal formülü hangisidir?', array['H2O', 'CO2', 'O2', 'NaCl'], 0, 'Bilim'),
  ('20000000-0000-4000-8000-000000000004', null, 'Türkiye Cumhuriyeti hangi yıl ilan edildi?', array['1919', '1920', '1923', '1938'], 2, 'Tarih'),
  ('20000000-0000-4000-8000-000000000005', null, 'Güneş sistemindeki en büyük gezegen hangisidir?', array['Mars', 'Jüpiter', 'Satürn', 'Venüs'], 1, 'Bilim'),
  ('20000000-0000-4000-8000-000000000006', null, 'Bir futbol takımı sahaya kaç oyuncuyla çıkar?', array['9', '10', '11', '12'], 2, 'Spor'),
  ('20000000-0000-4000-8000-000000000007', null, 'İstanbul''u Avrupa ve Asya yakası olarak ikiye ayıran boğaz hangisidir?', array['Çanakkale Boğazı', 'İstanbul Boğazı', 'Kerç Boğazı', 'Cebelitarık Boğazı'], 1, 'Coğrafya'),
  ('20000000-0000-4000-8000-000000000008', null, 'Işığın boşluktaki hızı yaklaşık kaç km/sn''dir?', array['3.000', '30.000', '300.000', '3.000.000'], 2, 'Bilim'),
  ('20000000-0000-4000-8000-000000000009', null, '"Nutuk" kimin eseridir?', array['Mustafa Kemal Atatürk', 'Ziya Gökalp', 'Namık Kemal', 'Mehmet Akif Ersoy'], 0, 'Tarih'),
  ('20000000-0000-4000-8000-000000000010', null, 'İstiklal Marşı''nın şairi kimdir?', array['Mehmet Akif Ersoy', 'Yahya Kemal Beyatlı', 'Nazım Hikmet', 'Orhan Veli'], 0, 'Edebiyat'),
  ('20000000-0000-4000-8000-000000000011', null, 'Bir gün kaç saattir?', array['12', '20', '24', '36'], 2, 'Genel kültür'),
  ('20000000-0000-4000-8000-000000000012', null, 'Dünya''nın doğal uydusunun adı nedir?', array['Ay', 'Titan', 'Phobos', 'Europa'], 0, 'Bilim'),
  ('20000000-0000-4000-8000-000000000013', null, 'Türkiye''nin en yüksek dağı hangisidir?', array['Erciyes', 'Uludağ', 'Ağrı Dağı', 'Palandöken'], 2, 'Coğrafya'),
  ('20000000-0000-4000-8000-000000000014', null, 'Basketbolda başarılı bir serbest atış kaç sayıdır?', array['1', '2', '3'], 0, 'Spor'),
  ('20000000-0000-4000-8000-000000000015', null, 'Bilgisayarda 1 bayt kaç bittir?', array['4', '8', '16', '32'], 1, 'Bilim'),
  ('20000000-0000-4000-8000-000000000016', null, 'Periyodik tabloda "Fe" simgesi hangi elementindir?', array['Flor', 'Demir', 'Fosfor', 'Kurşun'], 1, 'Bilim')
on conflict (id) do nothing;

-- Örnek görevler (Adım 9): tüm okullara açık, SP ödüllü. Rakamlar taslak (KARARLAR "Görevler").
insert into public.quests (id, school_id, title, description, period, action, target, reward_currency, reward_amount) values
  ('30000000-0000-4000-8000-000000000001', null, 'Günün tahminini yap', 'Bugünün Evet / Hayır sorusuna katıl', 'daily', 'prediction', 1, 'SP', 20),
  ('30000000-0000-4000-8000-000000000002', null, 'İki bahse katıl', 'Resmi, sosyal ya da günün tahmini', 'daily', 'wager', 2, 'SP', 30),
  ('30000000-0000-4000-8000-000000000003', null, 'Üç düello oyna', 'Trivia düellosunda soruları cevapla', 'weekly', 'duel', 3, 'SP', 80),
  ('30000000-0000-4000-8000-000000000004', null, 'Sosyal bahis aç', 'Okul arkadaşların için bir soru sor', 'weekly', 'social_bet', 1, 'SP', 50),
  ('30000000-0000-4000-8000-000000000005', null, 'Üç bahis kazan', 'Kazandığın bahisler ve düellolar sayılır', 'weekly', 'win', 3, 'SP', 150)
on conflict (id) do nothing;

-- Örnek kozmetikler (Adım 9): tüm okullara açık; SP vitrini ve SSP özel vitrini. Fiyatlar taslak.
insert into public.market_items (id, school_id, name, description, category, icon, color, price, currency) values
  ('40000000-0000-4000-8000-000000000001', null, 'Kehanet Ustası', 'Adının altında görünen unvan', 'title', '🔮', null, 600, 'SP'),
  ('40000000-0000-4000-8000-000000000002', null, 'Seri Avcısı', 'Profilinde rozet', 'badge', '🔥', null, 250, 'SP'),
  ('40000000-0000-4000-8000-000000000003', null, 'Altın çerçeve', 'Profil resmine altın çerçeve', 'frame', null, '#D4AF37', 400, 'SP'),
  ('40000000-0000-4000-8000-000000000004', null, 'Zümrüt çerçeve', 'Profil resmine yeşil çerçeve', 'frame', null, '#2E7D32', 300, 'SP'),
  ('40000000-0000-4000-8000-000000000005', null, 'Mor isim', 'Adın mor görünür', 'name_color', null, '#7E57C2', 350, 'SP'),
  ('40000000-0000-4000-8000-000000000006', null, 'Gece mavisi isim', 'Adın lacivert görünür', 'name_color', null, '#1565C0', 350, 'SP'),
  ('40000000-0000-4000-8000-000000000007', null, 'Kampüs Efsanesi', 'Yalnızca SSP ile alınan unvan', 'title', '👑', null, 150, 'SSP'),
  ('40000000-0000-4000-8000-000000000008', null, 'Turnuva Yıldızı', 'Yalnızca SSP ile alınan rozet', 'badge', '🏆', null, 80, 'SSP')
on conflict (id) do nothing;
