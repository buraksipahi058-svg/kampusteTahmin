-- Okul olmayan küme üst kümesiz ya da var olmayan bir üst kümeyle eklenirse
-- "school_id boş olamaz" yerine anlaşılır bir hata ver.
create or replace function private.clusters_set_school() returns trigger
language plpgsql set search_path = '' as $$
begin
  if tg_op = 'UPDATE' then
    if new.type is distinct from old.type
       or new.parent_cluster_id is distinct from old.parent_cluster_id
       or new.school_id is distinct from old.school_id then
      raise exception 'Küme türü ve üst kümesi değiştirilemez' using errcode = '23514';
    end if;
    return new;
  end if;

  if new.type = 'school' then
    new.school_id := new.id;
    return new;
  end if;

  if new.parent_cluster_id is null then
    raise exception 'Okul dışındaki kümelerin bir üst kümesi olmalı' using errcode = '23514';
  end if;

  select c.school_id into new.school_id from public.clusters c where c.id = new.parent_cluster_id;
  if new.school_id is null then
    raise exception 'Üst küme bulunamadı: %', new.parent_cluster_id using errcode = '23503';
  end if;
  return new;
end;
$$;
