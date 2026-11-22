-- Adım 8: trivia sorularını yönetme izni. Yeni enum değeri aynı transaction'da kullanılamadığı için
-- (RLS politikası, fonksiyonlar) ayrı migration'da eklenir.
alter type public.permission_key add value if not exists 'trivia_yonet';
