CREATE FUNCTION public.get_courier_unremitted_financial_summary (
  p_tenant_id bigint
)
  RETURNS TABLE (
    courier_service_id      uuid,
    courier_name            text,
    gross_cod_total         numeric,
    company_wholesale_total numeric,
    middleman_margin_total  numeric,
    order_count             bigint
  )
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  if p_tenant_id is null then
    raise exception 'Tenant ID is required';
  end if;

  return query
  select
    so.courier_service_id,
    coalesce(cs.name, so.courier_name, 'Unassigned') as courier_name,
    coalesce(sum(coalesce(so.cod_collect_amount, gi.total_amount, 0)), 0.00)::numeric(12,2) as gross_cod_total,
    (
      coalesce(sum(coalesce(so.cod_collect_amount, gi.total_amount, 0)), 0.00) -
      coalesce(sum(coalesce(wl.amount, 0)), 0.00)
    )::numeric(12,2) as company_wholesale_total,
    coalesce(sum(coalesce(wl.amount, 0)), 0.00)::numeric(12,2) as middleman_margin_total,
    count(so.id)::bigint as order_count
  from public.shop_orders so
  left join public.courier_services cs on cs.id = so.courier_service_id
  left join public.bills gi on gi.id = so.global_invoice_id
  left join public.billing_profile_wallet_ledger wl
    on wl.shop_order_id = so.id and wl.transaction_type = 'dropship_profit'
  where so.tenant_id = p_tenant_id
    and so.status = 'delivered'
  group by so.courier_service_id, coalesce(cs.name, so.courier_name, 'Unassigned');
end;
$function$;

GRANT ALL ON FUNCTION public.get_courier_unremitted_financial_summary(bigint) TO anon;

GRANT ALL ON FUNCTION public.get_courier_unremitted_financial_summary(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.get_courier_unremitted_financial_summary(bigint) TO service_role;