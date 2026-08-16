-- Header rate columns were dropped from global_shipments (20270814000030).
-- list_global_invoice_items still selected them. Return nulls to keep the contract.

begin;

create or replace function public.list_global_invoice_items(p_invoice_id bigint)
returns table (
  id bigint,
  invoice_id bigint,
  global_stock_id bigint,
  name_snapshot text,
  quantity numeric,
  sell_price_amount numeric,
  recipient_price_amount numeric,
  line_face_total_amount numeric,
  line_discount_amount numeric,
  line_total_amount numeric,
  return_quantity numeric,
  image_url text,
  shipment_id bigint,
  shipment_item_id bigint,
  purchase_price numeric,
  product_weight numeric,
  package_weight numeric,
  ordered_quantity integer,
  shipment_type text,
  product_conversion_rate numeric,
  cargo_conversion_rate numeric,
  cargo_rate numeric,
  received_weight numeric,
  transaction_rate numeric
)
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_parent_tenant_id bigint;
  v_tenant_id bigint;
  v_issued_by bigint;
begin
  select parent_tenant_id, tenant_id, issued_by_tenant_id
  into v_parent_tenant_id, v_tenant_id, v_issued_by
  from public.sales_invoices
  where public.sales_invoices.id = p_invoice_id;

  if not found then
    raise exception 'Invoice with ID % not found', p_invoice_id;
  end if;

  if not (
    public.user_can_manage_parent_tenant(v_parent_tenant_id)
    or public.user_can_manage_parent_tenant(v_tenant_id)
    or public.has_active_tenant_membership(v_issued_by)
    or public.membership_has_module_action(v_issued_by, 'global_invoice', 'view')
  ) then
    raise exception 'Access denied for invoice with ID %', p_invoice_id;
  end if;

  return query
  select
    gii.id,
    gii.invoice_id,
    gii.global_stock_id,
    gii.name_snapshot,
    gii.quantity,
    gii.sell_price_amount,
    gii.sell_price_amount as recipient_price_amount,
    gii.line_total_amount as line_face_total_amount,
    gii.line_discount_amount,
    gii.line_total_amount,
    gii.return_quantity,
    coalesce(gsi.image_url, p.image_url) as image_url,
    gsi.shipment_id,
    gsi.id as shipment_item_id,
    gsi.purchase_price,
    gsi.product_weight,
    gsi.package_weight,
    gsi.ordered_quantity,
    gship.type::text as shipment_type,
    null::numeric as product_conversion_rate,
    null::numeric as cargo_conversion_rate,
    null::numeric as cargo_rate,
    gship.received_weight,
    null::numeric as transaction_rate
  from public.sales_invoice_items gii
  left join public.global_stocks gs on gs.id = gii.global_stock_id
  left join public.global_shipment_items gsi
    on gsi.id = coalesce(gii.shipment_item_id, gs.shipment_item_id)
  left join public.global_shipments gship on gship.id = gsi.shipment_id
  left join public.products p on p.id = gii.product_id
  where gii.invoice_id = p_invoice_id
  order by gii.id;
end;
$$;

grant execute on function public.list_global_invoice_items(bigint) to authenticated, service_role;

commit;
