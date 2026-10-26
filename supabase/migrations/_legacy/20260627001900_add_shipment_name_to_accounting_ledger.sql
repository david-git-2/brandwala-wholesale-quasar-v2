-- Migration: Add shipment_name to v_shipment_accounting_ledger view
begin;

-- Drop view and dependencies
drop view if exists public.v_shipment_accounting_ledger cascade;

-- Recreate view with security_invoker = true and join shipments for shipment_name
create or replace view public.v_shipment_accounting_ledger
with (security_invoker = true) as
select
  iae.type,
  iae.id,
  iae.tenant_id,
  coalesce(iae.invoice_id, iae.commerce_invoice_id) as invoice_id,
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
  s.name as shipment_name,
  iae.shipment_item_id,
  iae.entry_date,
  iae.note,
  iae.created_at,
  iae.delivery_charge,
  iae.wrapping_charge,
  iae.cod,
  iae.discount_amount,
  iae.print_charge,
  iae.is_charges
from public.inventory_accounting_entries iae
left join public.shipments s on s.id = iae.shipment_id;

-- Grant permissions to authenticated role
grant select on table public.v_shipment_accounting_ledger to authenticated;

-- Notify PostgREST to reload schema cache
notify pgrst, 'reload schema';

commit;
