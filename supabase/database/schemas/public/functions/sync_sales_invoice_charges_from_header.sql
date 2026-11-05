CREATE FUNCTION public.sync_sales_invoice_charges_from_header (
  p_invoice_id bigint
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_inv public.bills;
  v_total numeric(12,2) := 0;
begin
  select * into v_inv from public.bills where id = p_invoice_id;
  if not found then
    return;
  end if;

  delete from public.bill_lines
  where invoice_id = p_invoice_id
    and line_kind = 'charge';

  if coalesce(v_inv.shipping_charge, 0) > 0 then
    insert into public.bill_lines (
      invoice_id, parent_tenant_id, line_kind, name_snapshot, quantity,
      sell_price_amount, line_discount_amount, line_total_amount, books_amount,
      currency_code, line_meta
    ) values (
      p_invoice_id, v_inv.parent_tenant_id, 'charge', 'Delivery', 1,
      v_inv.shipping_charge, 0, v_inv.shipping_charge, v_inv.shipping_charge,
      coalesce(v_inv.currency_code, 'BDT'), jsonb_build_object('charge_type', 'delivery')
    );
    v_total := v_total + v_inv.shipping_charge;
  end if;

  if coalesce(v_inv.print_charge, 0) > 0 then
    insert into public.bill_lines (
      invoice_id, parent_tenant_id, line_kind, name_snapshot, quantity,
      sell_price_amount, line_discount_amount, line_total_amount, books_amount,
      currency_code, line_meta
    ) values (
      p_invoice_id, v_inv.parent_tenant_id, 'charge', 'Print', 1,
      v_inv.print_charge, 0, v_inv.print_charge, v_inv.print_charge,
      coalesce(v_inv.currency_code, 'BDT'), jsonb_build_object('charge_type', 'print')
    );
    v_total := v_total + v_inv.print_charge;
  end if;

  if coalesce(v_inv.wrapping_charge, 0) > 0 then
    insert into public.bill_lines (
      invoice_id, parent_tenant_id, line_kind, name_snapshot, quantity,
      sell_price_amount, line_discount_amount, line_total_amount, books_amount,
      currency_code, line_meta
    ) values (
      p_invoice_id, v_inv.parent_tenant_id, 'charge', 'Packing', 1,
      v_inv.wrapping_charge, 0, v_inv.wrapping_charge, v_inv.wrapping_charge,
      coalesce(v_inv.currency_code, 'BDT'), jsonb_build_object('charge_type', 'packing')
    );
    v_total := v_total + v_inv.wrapping_charge;
  end if;

  update public.bills
  set charges_amount = v_total,
      updated_at = now()
  where id = p_invoice_id;
end;
$function$;

GRANT ALL ON FUNCTION public.sync_sales_invoice_charges_from_header(bigint) TO anon;

GRANT ALL ON FUNCTION public.sync_sales_invoice_charges_from_header(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.sync_sales_invoice_charges_from_header(bigint) TO service_role;