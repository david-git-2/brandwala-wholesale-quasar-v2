alter table public.product_based_costing_items
  add column if not exists input_type text null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'product_based_costing_items_input_type_check'
  ) then
    alter table public.product_based_costing_items
      add constraint product_based_costing_items_input_type_check
      check (input_type in ('manual', 'product_list') or input_type is null);
  end if;
end $$;

update public.product_based_costing_items
set input_type = 'product_list'
where input_type is null and product_id is not null;

update public.product_based_costing_items
set input_type = 'manual'
where input_type is null and product_id is null;
