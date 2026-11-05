CREATE FUNCTION public.update_global_invoice_item (
  p_item_id                bigint,
  p_quantity               numeric,
  p_sell_price_amount      numeric,
  p_recipient_price_amount numeric DEFAULT NULL::numeric
)
  RETURNS public.bill_lines
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_item public.bill_lines;
  v_invoice public.bills;
  v_line_total numeric;
begin
  select * into v_item from public.bill_lines where id = p_item_id;
  if v_item.id is null then raise exception 'Invoice item not found'; end if;

  select * into v_invoice from public.bills where id = v_item.invoice_id;
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

  update public.bill_lines
  set
    quantity = p_quantity,
    sell_price_amount = p_sell_price_amount,
    line_total_amount = v_line_total
  where id = p_item_id
  returning * into v_item;

  perform public.recompute_global_invoice_totals(v_item.invoice_id);

  return v_item;
end;
$function$;

GRANT ALL ON FUNCTION public.update_global_invoice_item(bigint, numeric, numeric, numeric) TO anon;

GRANT ALL ON FUNCTION public.update_global_invoice_item(bigint, numeric, numeric, numeric) TO authenticated;

GRANT ALL ON FUNCTION public.update_global_invoice_item(bigint, numeric, numeric, numeric) TO service_role;