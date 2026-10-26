-- Migration: Remove redundant stock_override from products table and secure shipment accounting view
begin;

-- 1. Drop the stock_override column from products table
alter table public.products drop column if exists stock_override;

-- 2. Drop legacy v_shipment_accounting_ledger standard view
drop view if exists public.v_shipment_accounting_ledger;

-- 3. Recreate v_shipment_accounting_ledger with security_invoker option enabled (PG 15+)
create or replace view public.v_shipment_accounting_ledger
with (security_invoker = true) as
select
  'normal'::text as type,
  iae.id,
  iae.tenant_id,
  iae.invoice_id,
  iae.invoice_item_id,
  iae.inventory_item_id,
  iae.product_id,
  iae.quantity,
  iae.cost_amount,
  iae.sell_price_amount,
  iae.total_cost_amount,
  iae.total_sell_amount,
  iae.gross_profit_amount,
  iae.status,
  iae.shipment_id,
  iae.shipment_item_id,
  iae.entry_date,
  iae.note,
  iae.created_at
from public.inventory_accounting_entries iae

union all

select
  'commerce'::text as type,
  ca.id,
  ca.tenant_id,
  coi.invoice_id,
  null::bigint as invoice_item_id,
  ca.inventory_item_id,
  coi.product_id,
  coi.quantity::numeric(12,3) as quantity,
  ca.cost_bdt as cost_amount,
  ca.sell_price_bdt as sell_price_amount,
  (ca.cost_bdt * coi.quantity) as total_cost_amount,
  (ca.sell_price_bdt * coi.quantity) as total_sell_amount,
  ((ca.sell_price_bdt - ca.cost_bdt) * coi.quantity) as gross_profit_amount,
  case when ca.is_customer_group_paid then 'paid'::text else 'due'::text end as status,
  si.shipment_id,
  ca.shipment_item_id,
  ca.created_at::date as entry_date,
  'Commerce Invoice Item'::text as note,
  ca.created_at
from public.commerce_accounting ca
join public.commerce_order_items coi on coi.id = ca.order_item_id
left join public.shipment_items si on si.id = ca.shipment_item_id;

-- 4. Re-grant select access to authenticated users
grant select on table public.v_shipment_accounting_ledger to authenticated;

commit;
