-- Migration: Secure commerce_accounting view using security_invoker
begin;

-- Drop view and dependencies (triggers)
drop view if exists public.commerce_accounting cascade;

-- Recreate view with security_invoker = true
create or replace view public.commerce_accounting
with (security_invoker = true) as
select
  id,
  commerce_order_item_id as order_item_id,
  cost_amount as cost_bdt,
  shipment_item_id,
  sell_price_amount as sell_price_bdt,
  recipient_sell_price_amount as recipient_sell_price_bdt,
  customer_group_id,
  billing_profile_id,
  (status = 'paid') as is_customer_group_paid,
  tenant_id,
  inventory_item_id,
  created_at,
  updated_at
from public.inventory_accounting_entries
where type = 'commerce';

-- Recreate the instead of trigger
create trigger trg_commerce_accounting_instead_of
  instead of insert or update or delete
  on public.commerce_accounting
  for each row
  execute function public.trg_fn_commerce_accounting_instead_of();

-- Grant permissions to authenticated role
grant select, insert, update, delete on table public.commerce_accounting to authenticated;

-- Notify PostgREST to reload schema cache
notify pgrst, 'reload schema';

commit;
