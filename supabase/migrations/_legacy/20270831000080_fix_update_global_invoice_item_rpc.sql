-- Migration: 20270831000080_fix_update_global_invoice_item_rpc.sql
-- Description: Fix update_global_invoice_item return record type mismatch and allow draft/proforma item updates

CREATE OR REPLACE FUNCTION "public"."update_global_invoice_item"(
  "p_item_id" bigint,
  "p_quantity" numeric,
  "p_sell_price_amount" numeric,
  "p_recipient_price_amount" numeric DEFAULT NULL::numeric
) RETURNS "public"."sales_invoice_items"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_item public.sales_invoice_items;
  v_invoice public.sales_invoices;
  v_line_total numeric;
begin
  select * into v_item from public.sales_invoice_items where id = p_item_id;
  if v_item.id is null then raise exception 'Invoice item not found'; end if;

  select * into v_invoice from public.sales_invoices where id = v_item.invoice_id;
  if v_invoice.id is null then raise exception 'Invoice not found'; end if;
  if v_invoice.invoice_status not in ('draft'::public.global_invoice_status, 'proforma_generated'::public.global_invoice_status) then
    raise exception 'Cannot edit items on a posted or voided invoice';
  end if;

  if p_quantity <= 0 then
    raise exception 'Quantity must be greater than 0';
  end if;

  if p_sell_price_amount < 0 then
    raise exception 'Sell price cannot be negative';
  end if;

  v_line_total := greatest((p_quantity * p_sell_price_amount) - coalesce(v_item.line_discount_amount, 0.00), 0.00);

  update public.sales_invoice_items
  set
    quantity = p_quantity,
    sell_price_amount = p_sell_price_amount,
    line_total_amount = v_line_total
  where id = p_item_id
  returning * into v_item;

  perform public.recompute_global_invoice_totals(v_item.invoice_id);

  return v_item;
end;
$$;

ALTER FUNCTION "public"."update_global_invoice_item"("p_item_id" bigint, "p_quantity" numeric, "p_sell_price_amount" numeric, "p_recipient_price_amount" numeric) OWNER TO "postgres";
GRANT ALL ON FUNCTION "public"."update_global_invoice_item"("p_item_id" bigint, "p_quantity" numeric, "p_sell_price_amount" numeric, "p_recipient_price_amount" numeric) TO "authenticated";
