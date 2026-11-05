CREATE FUNCTION public.credit_dropship_profit_from_courier_remittance (
  p_tenant_id         bigint,
  p_profile_id        bigint,
  p_order_id          bigint,
  p_payment_id        bigint,
  p_amount            numeric,
  p_reference         text,
  p_net_remitted      numeric,
  p_invoice_allocated numeric
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_parent_id bigint;
  v_profit_already_credited boolean := false;
  v_amount numeric(12, 2);
begin
  v_amount := round(greatest(coalesce(p_amount, 0), 0), 2);
  if v_amount <= 0 then
    return;
  end if;

  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);

  select exists (
    select 1
    from public.cashbook_entries u
    where u.parent_tenant_id = v_parent_id
      and u.source_type = 'shop_order'
      and u.source_id = p_order_id::text
      and u.entity_type in ('middleman', 'customer')
      and u.entity_id = p_profile_id
      and u.type = 'credit'
      and coalesce(u.metadata ->> 'transaction_type', '') = 'dropship_profit'
  ) into v_profit_already_credited;

  if v_profit_already_credited then
    return;
  end if;

  perform public.record_ledger_transaction(
    p_parent_tenant_id => v_parent_id,
    p_operating_tenant_id => p_tenant_id,
    p_entity_type => 'customer',
    p_entity_id => p_profile_id,
    p_type => 'credit',
    p_amount => v_amount,
    p_currency_code => 'BDT',
    p_exchange_rate => 1.000000,
    p_source_type => 'shop_order',
    p_source_id => p_order_id::text,
    p_metadata => jsonb_build_object(
      'section', 'payout_earned',
      'transaction_type', 'dropship_profit',
      'label', 'Dropship profit from remittance remainder',
      'order_id', p_order_id,
      'shop_order_id', p_order_id::text,
      'payment_id', p_payment_id,
      'remittance_ref', p_reference,
      'net_remitted', p_net_remitted,
      'invoice_allocated', p_invoice_allocated
    )
  );
end;
$function$;

GRANT ALL ON FUNCTION public.credit_dropship_profit_from_courier_remittance(bigint, bigint, bigint, bigint, numeric, text, numeric, numeric) TO anon;

GRANT ALL ON FUNCTION public.credit_dropship_profit_from_courier_remittance(bigint, bigint, bigint, bigint, numeric, text, numeric, numeric) TO authenticated;

GRANT ALL ON FUNCTION public.credit_dropship_profit_from_courier_remittance(bigint, bigint, bigint, bigint, numeric, text, numeric, numeric) TO service_role;