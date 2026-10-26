-- =========================================================
-- Add extra descriptive fields to costing_file_items
-- =========================================================

alter table public.costing_file_items
  add column if not exists size text,
  add column if not exists color text,
  add column if not exists extra_information_1 text,
  add column if not exists extra_information_2 text;

create or replace function public.normalize_costing_file_item_fields()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.website_url := trim(coalesce(new.website_url, ''));

  if new.image_url is not null then
    new.image_url := nullif(trim(new.image_url), '');
  end if;

  if new.name is not null then
    new.name := nullif(trim(new.name), '');
  end if;

  if new.size is not null then
    new.size := nullif(trim(new.size), '');
  end if;

  if new.color is not null then
    new.color := nullif(trim(new.color), '');
  end if;

  if new.extra_information_1 is not null then
    new.extra_information_1 := nullif(trim(new.extra_information_1), '');
  end if;

  if new.extra_information_2 is not null then
    new.extra_information_2 := nullif(trim(new.extra_information_2), '');
  end if;

  return new;
end;
$$;
