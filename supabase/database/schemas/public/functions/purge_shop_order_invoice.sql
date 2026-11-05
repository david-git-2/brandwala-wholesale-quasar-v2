CREATE FUNCTION public.purge_shop_order_invoice (
  p_invoice_id bigint
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_invoice public.bills;
  v_payment_ids bigint[];
begin
  if p_invoice_id is null then
    return;
  end if;

  select * into v_invoice
  from public.bills
  where id = p_invoice_id
  for update;

  if v_invoice.id is null then
    return;
  end if;

  select coalesce(array_agg(distinct ip.payment_id), '{}'::bigint[])
  into v_payment_ids
  from public.pay_allocations ip
  where ip.global_invoice_id = p_invoice_id;

  delete from public.pay_allocations
  where global_invoice_id = p_invoice_id;

  delete from public.pays gp
  where gp.id = any (v_payment_ids)
    and not exists (
      select 1
      from public.pay_allocations ip
      where ip.payment_id = gp.id
    );

  update public.bills
  set
    paid_amount = 0.00,
    payment_status = 'due',
    due_amount = coalesce(total_amount, 0.00),
    updated_at = now()
  where id = p_invoice_id;

  if v_invoice.invoice_status = 'issued'::public.global_invoice_status then
    perform public.unpost_global_invoice(p_invoice_id);
  end if;

  delete from public.global_return_items where invoice_id = p_invoice_id;
  delete from public.global_invoice_items where invoice_id = p_invoice_id;
  delete from public.bills where id = p_invoice_id;
end;
$function$;

GRANT ALL ON FUNCTION public.purge_shop_order_invoice(bigint) TO anon;

GRANT ALL ON FUNCTION public.purge_shop_order_invoice(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.purge_shop_order_invoice(bigint) TO service_role;