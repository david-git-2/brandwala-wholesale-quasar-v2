CREATE FUNCTION public.get_my_dropship_wallet_summary()
  RETURNS TABLE (
    profile_id        bigint,
    available_balance numeric,
    pending_balance   numeric,
    locked_balance    numeric,
    currency          text
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_email text := public.current_user_email();
  v_tenant_id bigint;
  v_group_id bigint;
  v_bp_id bigint;
  v_available numeric := 0;
  v_pending numeric := 0;
  v_locked numeric := 0;
begin
  if v_email is null or length(trim(v_email)) = 0 then
    raise exception 'Not authenticated';
  end if;

  select cg.tenant_id, cgm.customer_group_id
  into v_tenant_id, v_group_id
  from public.customer_group_members cgm
  join public.customer_groups cg on cg.id = cgm.customer_group_id
  where lower(trim(cgm.email)) = lower(trim(v_email))
    and cgm.is_active = true
    and cg.is_active = true
  order by cgm.id
  limit 1;

  if v_tenant_id is null or v_group_id is null then
    raise exception 'No active customer group membership';
  end if;

  v_bp_id := public.resolve_customer_profile_for_group(v_tenant_id, v_group_id);
  if v_bp_id is null then
    raise exception 'No billing profile linked for your customer group';
  end if;

  select coalesce(w.available_balance, 0)
  into v_available
  from public.cashbook_accounts w
  where w.parent_tenant_id = public.resolve_parent_tenant_id(v_tenant_id)
    and w.entity_type = 'customer'
    and w.entity_id = v_bp_id
    and w.currency_code = 'BDT';

  select coalesce(sum(s.reseller_profit), 0)
  into v_pending
  from public.shop_orders o
  join public.dropship_order_settlements s on s.shop_order_id = o.id
  where o.tenant_id = v_tenant_id
    and o.profile_id = v_bp_id
    and o.shop_type_snapshot = 'dropship'
    and o.status = 'payment_received'::public.shop_order_status
    and coalesce(s.reseller_profit, 0) > 0
    and s.merchant_payout_at is null;

  select coalesce(sum(greatest(coalesce(o.cod_collect_amount, 0), 0)), 0)
  into v_locked
  from public.shop_orders o
  where o.tenant_id = v_tenant_id
    and o.profile_id = v_bp_id
    and o.shop_type_snapshot = 'dropship'
    and o.status = 'delivered'
    and o.courier_remittance_ref is null
    and coalesce(o.collection_source, 'recipient') = 'recipient';

  return query select
    v_bp_id,
    v_available,
    v_pending,
    v_locked,
    'BDT'::text;
end;
$function$;

GRANT ALL ON FUNCTION public.get_my_dropship_wallet_summary() TO anon;

GRANT ALL ON FUNCTION public.get_my_dropship_wallet_summary() TO authenticated;

GRANT ALL ON FUNCTION public.get_my_dropship_wallet_summary() TO service_role;