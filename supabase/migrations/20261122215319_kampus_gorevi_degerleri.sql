-- Adım 17a hazırlık: kampüs görevleri için enum değerleri (yeni değer aynı transaction'da kullanılamadığı için ayrı).

alter type public.permission_key add value if not exists 'kampus_gorevi_yonet';
alter type public.ledger_reason add value if not exists 'campus_task_reward';
alter type public.ledger_ref_type add value if not exists 'campus_task';
alter type public.xp_reason add value if not exists 'campus_task';
