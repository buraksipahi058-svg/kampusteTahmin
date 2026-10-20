-- Geliştirme verisi: MVP tek okulla başlar (MIMARI §2.5). Gerçek okul belli olunca ad ve alan adı güncellenir.
-- Tekrar çalıştırılabilir.

insert into public.clusters (id, name, type)
values ('10000000-0000-4000-8000-000000000001', 'Örnek Üniversitesi', 'school')
on conflict (id) do nothing;

insert into public.school_email_domains (domain, school_id)
values ('ogr.ornek.edu.tr', '10000000-0000-4000-8000-000000000001')
on conflict (domain) do nothing;
