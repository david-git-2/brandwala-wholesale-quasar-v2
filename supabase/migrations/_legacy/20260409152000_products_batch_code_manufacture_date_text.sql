begin;

alter table public.products
  alter column batch_code_manufacture_date type text
  using batch_code_manufacture_date::text;

commit;
