-- Adım 19: Kampüs kelimesi için enum değerleri. Ayrı migration: yeni enum değeri aynı transaction'da kullanılamaz.

alter type public.permission_key add value if not exists 'kelime_yonet';
alter type public.ledger_reason add value if not exists 'word_reward';
alter type public.ledger_ref_type add value if not exists 'word_puzzle';
alter type public.xp_reason add value if not exists 'word_puzzle';
