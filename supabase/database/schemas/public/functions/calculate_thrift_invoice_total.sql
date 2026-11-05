CREATE FUNCTION public.calculate_thrift_invoice_total()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  AS $function$
declare
  v_invoice_id bigint;
begin
  if tg_op = 'DELETE' then
    v_invoice_id := old.invoice_id;
  else
    v_invoice_id := new.invoice_id;
  end if;

  update public.thrift_invoices
  set total_invoice_amount = coalesce((
    select sum(sold_price * quantity)
    from public.thrift_invoice_items
    where invoice_id = v_invoice_id
  ), 0.00) 
  + cod_charge 
  + packing_charge 
  + invoice_print_charge 
  + shipping_charge_customer
  where id = v_invoice_id;

  return null;
end;
$function$;

GRANT ALL ON FUNCTION public.calculate_thrift_invoice_total() TO anon;

GRANT ALL ON FUNCTION public.calculate_thrift_invoice_total() TO authenticated;

GRANT ALL ON FUNCTION public.calculate_thrift_invoice_total() TO service_role;