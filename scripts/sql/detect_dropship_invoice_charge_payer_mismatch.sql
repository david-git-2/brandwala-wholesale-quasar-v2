-- Detect dropship orders where a non-merchant-paid settlement charge
-- is still billed on the linked tenant B2B invoice header.
--
-- Run against local or prod (read-only):
--   docker exec supabase_db_brandwala-wholesale-quasar psql -U postgres -d postgres -f /path/to/this/file

select
  o.id as order_id,
  o.order_no,
  o.status,
  i.id as invoice_id,
  i.invoice_no,
  i.total_amount,
  i.paid_amount,
  i.shipping_charge,
  i.print_charge,
  i.wrapping_charge,
  i.cod_charge_amount,
  cl.charge_type,
  cl.amount as charge_line_amount,
  cl.payer,
  s.reseller_profit,
  (u.metadata->>'merchant_funds_held')::numeric as merchant_funds_held,
  s.reseller_profit - coalesce((u.metadata->>'merchant_funds_held')::numeric, 0) as profit_minus_held
from public.shop_orders o
inner join public.dropship_order_settlements s on s.shop_order_id = o.id
inner join public.dropship_settlement_charge_lines cl on cl.settlement_id = s.id
inner join public.sales_invoices i on i.id = o.global_invoice_id
left join public.universal_wallet_ledger u
  on u.source_type = 'shop_order'
  and u.source_id = o.id::text
  and u.metadata->>'purpose' = 'tenant_remittance_received'
where o.shop_type_snapshot = 'dropship'
  and cl.payer <> 'merchant'
  and (
    (cl.charge_type = 'cod' and coalesce(i.cod_charge_amount, 0) > 0)
    or (cl.charge_type = 'print' and coalesce(i.print_charge, 0) > 0)
    or (cl.charge_type = 'packing' and coalesce(i.wrapping_charge, 0) > 0)
    or (cl.charge_type = 'delivery' and coalesce(i.shipping_charge, 0) > 0)
  )
order by o.id, cl.charge_type;
