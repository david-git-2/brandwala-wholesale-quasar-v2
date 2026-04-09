begin;

alter table public.products
  alter column expire_date type text
  using expire_date::text;

commit;
