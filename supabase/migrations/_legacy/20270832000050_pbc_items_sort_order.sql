-- Add sort_order column to public.product_based_costing_items
alter table public.product_based_costing_items
  add column if not exists sort_order int not null default 0;

-- Create RPC to bulk update sort_order of product based costing items
create or replace function public.update_product_based_costing_items_order(
  p_items jsonb
) returns void as $$
declare
  item_row record;
begin
  for item_row in select * from jsonb_to_recordset(p_items) as x(id bigint, sort_order int) loop
    update public.product_based_costing_items
    set sort_order = item_row.sort_order
    where id = item_row.id;
  end loop;
end;
$$ language plpgsql security definer set search_path to 'public';

grant execute on function public.update_product_based_costing_items_order(jsonb) to authenticated;

notify pgrst, 'reload schema';
