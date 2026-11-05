CREATE FUNCTION public.purge_shop_order_financial_artifacts (
  p_order_id bigint
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_order public.shop_orders;
  v_invoice public.bills;
  v_invoice_id bigint;
begin
  select * into v_order
  from public.shop_orders
  where id = p_order_id;

  if v_order.id is null then
    return;
  end if;

  v_invoice_id := v_order.global_invoice_id;

  if v_invoice_id is null and v_order.shop_type_snapshot = 'dropship' then
    select i.id into v_invoice_id
    from public.bills i
    where i.parent_tenant_id = v_order.tenant_id
      and i.invoice_no = 'INV-DS-' || v_order.order_no
      and not exists (
        select 1
        from public.shop_orders o2
        where o2.global_invoice_id = i.id
          and o2.id <> v_order.id
      )
    order by i.id desc
    limit 1;
  end if;

  if v_invoice_id is not null then
    select * into v_invoice from public.bills where id = v_invoice_id;
  end if;

  delete from public.courier_remittance_items
  where shop_order_id = p_order_id;

  perform public.purge_shop_order_wallet_ledger(
    p_order_id => p_order_id,
    p_tenant_id => v_order.tenant_id,
    p_order_no => v_order.order_no,
    p_invoice_id => v_invoice_id,
    p_invoice_no => v_invoice.invoice_no
  );

  if v_invoice_id is not null then
    perform public.purge_shop_order_invoice(v_invoice_id);
  end if;
end;
$function$;

GRANT ALL ON FUNCTION public.purge_shop_order_financial_artifacts(bigint) TO anon;

GRANT ALL ON FUNCTION public.purge_shop_order_financial_artifacts(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.purge_shop_order_financial_artifacts(bigint) TO service_role;