-- Migration: 20270831000150_return_unit_cost_price_in_list_global_invoice_items.sql
-- Description: Add unit_cost_price to list_global_invoice_items RPC

DROP FUNCTION IF EXISTS "public"."list_global_invoice_items"("p_invoice_id" bigint);

CREATE OR REPLACE FUNCTION "public"."list_global_invoice_items"("p_invoice_id" bigint) RETURNS TABLE("id" bigint, "invoice_id" bigint, "global_stock_id" bigint, "name_snapshot" "text", "quantity" numeric, "sell_price_amount" numeric, "recipient_price_amount" numeric, "line_face_total_amount" numeric, "line_discount_amount" numeric, "line_total_amount" numeric, "return_quantity" numeric, "image_url" "text", "shipment_id" bigint, "shipment_item_id" bigint, "purchase_price" numeric, "product_weight" numeric, "package_weight" numeric, "ordered_quantity" integer, "shipment_type" "text", "product_conversion_rate" numeric, "cargo_conversion_rate" numeric, "cargo_rate" numeric, "received_weight" numeric, "transaction_rate" numeric, "available_atp" numeric, "unit_cost_price" numeric)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_parent_tenant_id bigint;
  v_issued_by bigint;
  v_invoice_status public.global_invoice_status;
begin
  select parent_tenant_id, issued_by_tenant_id, invoice_status
  into v_parent_tenant_id, v_issued_by, v_invoice_status
  from public.sales_invoices
  where public.sales_invoices.id = p_invoice_id;

  if not found then
    raise exception 'Invoice with ID % not found', p_invoice_id;
  end if;

  if not (
    public.user_can_manage_parent_tenant(v_parent_tenant_id)
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
    null::numeric as transaction_rate,
    case
      when gii.global_stock_id is null then 0::numeric
      -- For draft invoices, ATP available to this line includes warehouse stock + current draft qty
      when v_invoice_status in ('draft'::public.global_invoice_status, 'proforma_generated'::public.global_invoice_status)
        then (coalesce(public.global_stock_atp_qty(gii.global_stock_id), gs.quantity, 0) + gii.quantity)::numeric
      else (coalesce(public.global_stock_atp_qty(gii.global_stock_id), gs.quantity, 0))::numeric
    end as available_atp,
    coalesce(gii.unit_cost_price, gsi.landed_cost_bdt, gsi.purchase_price, 0)::numeric as unit_cost_price
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

ALTER FUNCTION "public"."list_global_invoice_items"("p_invoice_id" bigint) OWNER TO "postgres";
