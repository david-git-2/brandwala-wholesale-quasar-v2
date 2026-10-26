-- Migration: Shipment item invoices RPC for Sales Breakdown tab
-- Returns all invoice lines linked to a shipment's items, providing
-- per-invoice visibility into which invoices consumed stock from this batch.

create or replace function public.get_shipment_item_invoices(
  p_tenant_id bigint,
  p_shipment_id bigint
)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_parent_id bigint;
  v_rows jsonb;
begin
  -- Resolve parent tenant to enforce access
  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);

  if v_parent_id <> (select parent_tenant_id from public.global_shipments where id = p_shipment_id) then
    raise exception 'unauthorized tenant access to shipment';
  end if;

  select coalesce(jsonb_agg(row_to_json(r) order by r.invoice_date desc, r.invoice_id desc, r.shipment_item_id), '[]'::jsonb)
  into v_rows
  from (
    select
      si.id                          as shipment_item_id,
      si.name                        as shipment_item_name,
      si.product_code                as product_code,
      si.barcode                     as barcode,
      si.ordered_quantity             as ordered_quantity,
      inv.id                         as invoice_id,
      inv.invoice_no                 as invoice_no,
      inv.invoice_date               as invoice_date,
      inv.invoice_type::text         as invoice_type,
      inv.invoice_status::text       as invoice_status,
      coalesce(bp.name, case
        when inv.collection_source = 'recipient' then coalesce(inv.recipient_name, 'Walk-in / Direct')
        else 'N/A'
      end)                           as buyer_name,
      ii.quantity                    as qty_sold,
      ii.return_quantity             as return_qty,
      (ii.quantity - ii.return_quantity) as net_sold,
      ii.unit_cost_price             as unit_cost_price,
      ii.sell_price_amount           as sell_price_amount,
      ii.line_discount_amount        as line_discount_amount,
      ii.line_total_amount           as line_total_amount
    from public.global_shipment_items si
    inner join public.global_invoice_items ii on ii.shipment_item_id = si.id
    inner join public.global_invoices inv on inv.id = ii.invoice_id
    left join public.billing_profiles bp on bp.id = inv.billing_profile_id
    where si.shipment_id = p_shipment_id
      and inv.invoice_status = 'posted'::public.global_invoice_status
  ) r;

  return v_rows;
end;
$$;

grant execute on function public.get_shipment_item_invoices(bigint, bigint) to authenticated;
grant execute on function public.get_shipment_item_invoices(bigint, bigint) to anon;
grant execute on function public.get_shipment_item_invoices(bigint, bigint) to service_role;
