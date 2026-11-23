-- Adım 16 hazırlık: başarım ödülü için enum değerleri. Yeni enum değeri eklendiği transaction'da kullanılamadığı
-- için ayrı migration (aynı kalıp: 20261122092401_trivia_izni.sql).

alter type public.ledger_reason add value if not exists 'achievement_reward';
alter type public.ledger_ref_type add value if not exists 'achievement';
alter type public.xp_reason add value if not exists 'achievement';
