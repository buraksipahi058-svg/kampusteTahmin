-- Adım 9 düzeltmesi: satıştan kaldırılan ürün, sahibine ve (kuşanılmışsa) okul arkadaşlarına görünmeye
-- devam eder; yoksa envanterdeki ürünün adı / simgesi / rengi okunamaz.
-- Alt sorgu user_inventory'nin kendi RLS'iyle çalışır: kişinin kendi satırları + okul arkadaşlarının
-- kuşanılmış satırları. Böylece ek koşul "sahibim ya da okulumdan biri kuşanmış" anlamına gelir.

drop policy market_items_select on public.market_items;

create policy market_items_select on public.market_items
  for select to authenticated
  using (
    (active and (school_id is null or school_id = (select private.current_school_id())))
    or (select private.is_superadmin())
    or (school_id is not null and private.has_permission(school_id, 'market_yonet'))
    or exists (select 1 from public.user_inventory i where i.item_id = market_items.id)
  );
