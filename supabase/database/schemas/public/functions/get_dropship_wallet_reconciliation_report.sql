CREATE FUNCTION public.get_dropship_wallet_reconciliation_report (
  p_tenant_id bigint DEFAULT NULL::bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_target_tenant_id bigint;
  v_missing_invoice_billed bigint := 0;
  v_missing_courier_remittance bigint := 0;
  v_missing_return_compensation bigint := 0;
  v_mixed_customer_profit bigint := 0;
  v_uncanonicalized_source_ids bigint := 0;
  v_conflicting_active_offers bigint := 0;
  v_missing_or_duplicate_gifts bigint := 0;
begin
  if p_tenant_id is not null then
    v_target_tenant_id := p_tenant_id;
  else
    v_target_tenant_id := public.current_tenant_id();
  end if;

  if not (
    public.is_superadmin()
    or exists (
      select 1 from public.memberships m
      where (v_target_tenant_id is null or m.tenant_id = v_target_tenant_id)
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
        and m.role in ('admin', 'staff')
    )
  ) then
    raise exception 'Permission denied: Admin or Staff role required for reconciliation report';
  end if;

  -- 1. Posted dropship invoices missing invoice_billed (P0A contract)
  select count(*) into v_missing_invoice_billed
  from public.bills i
  where i.invoice_type = 'dropship'
    and i.invoice_status = 'posted'
    and i.profile_id is not null
    and i.total_amount > 0
    and (v_target_tenant_id is null or i.tenant_id = v_target_tenant_id)
    and not exists (
      select 1 from public.cashbook_entries u
      where u.tenant_id = i.tenant_id
        and u.entity_type = 'customer'
        and u.entity_id = i.profile_id
        and u.source_type = 'shop_order'
        and u.metadata->>'transaction_type' = 'invoice_billed'
        and (u.metadata->>'invoice_id' = i.id::text or u.source_id = i.invoice_no)
    );

  -- 2. Remitted shop orders missing courier remittance UWL entry
  select count(*) into v_missing_courier_remittance
  from public.shop_orders o
  where o.shop_type_snapshot = 'dropship'
    and o.status = 'payment_received'
    and o.courier_remittance_ref is not null
    and (v_target_tenant_id is null or o.tenant_id = v_target_tenant_id)
    and not exists (
      select 1 from public.cashbook_entries u
      where u.tenant_id = o.tenant_id
        and u.entity_type = 'courier'
        and u.source_type = 'shop_order'
        and u.source_id = o.id::text
        and u.metadata->>'purpose' = 'courier_remittance'
    );

  -- 3. Finalized returns missing return compensating UWL entry
  select count(*) into v_missing_return_compensation
  from public.shop_orders o
  where o.shop_type_snapshot = 'dropship'
    and o.status = 'returned'
    and (v_target_tenant_id is null or o.tenant_id = v_target_tenant_id)
    and not exists (
      select 1 from public.cashbook_entries u
      where u.tenant_id = o.tenant_id
        and u.source_type = 'shop_order'
        and u.source_id = o.id::text
        and (
          u.metadata->>'purpose' = 'dropship_return_finalize'
          or u.metadata->>'transaction_type' in (
            'return_reversal',
            'return_profit_clawback',
            'return_revenue_reversal'
          )
        )
    );

  -- 4. Mixed customer vs middleman profit rows
  select count(*) into v_mixed_customer_profit
  from public.cashbook_entries u
  where u.entity_type = 'customer'
    and u.source_type = 'shop_order'
    and u.metadata->>'transaction_type' = 'dropship_profit'
    and (v_target_tenant_id is null or u.tenant_id = v_target_tenant_id);

  -- 5. Uncanonicalized source_ids (order_no instead of order_id string), exclude invoice_billed
  select count(*) into v_uncanonicalized_source_ids
  from public.cashbook_entries u
  join public.shop_orders o on o.tenant_id = u.tenant_id and o.order_no = u.source_id
  where u.source_type = 'shop_order'
    and coalesce(u.metadata->>'transaction_type', '') <> 'invoice_billed'
    and (v_target_tenant_id is null or u.tenant_id = v_target_tenant_id);

  -- 6. Conflicting active offer prices (P2 shop_product_offers)
  select count(*) into v_conflicting_active_offers
  from (
    select shop_id, product_id, condition_bucket
    from public.shop_product_offers
    where is_active = true
    group by shop_id, product_id, condition_bucket
    having count(*) > 1
  ) t;

  -- 7. Legacy gift rules removed - drift is 0
  v_missing_or_duplicate_gifts := 0;

  return jsonb_build_object(
    'reconciliation_time', now(),
    'tenant_id', v_target_tenant_id,
    'healthy', (
      v_missing_invoice_billed = 0 and
      v_missing_courier_remittance = 0 and
      v_missing_return_compensation = 0 and
      v_mixed_customer_profit = 0 and
      v_uncanonicalized_source_ids = 0 and
      v_conflicting_active_offers = 0 and
      v_missing_or_duplicate_gifts = 0
    ),
    'drift_counts', jsonb_build_object(
      'missing_invoice_billed', v_missing_invoice_billed,
      'missing_courier_remittance', v_missing_courier_remittance,
      'missing_return_compensation', v_missing_return_compensation,
      'mixed_customer_profit', v_mixed_customer_profit,
      'uncanonicalized_source_ids', v_uncanonicalized_source_ids,
      'conflicting_active_offers', v_conflicting_active_offers,
      'missing_or_duplicate_gifts', v_missing_or_duplicate_gifts
    )
  );
end;
$function$;

GRANT ALL ON FUNCTION public.get_dropship_wallet_reconciliation_report(bigint) TO anon;

GRANT ALL ON FUNCTION public.get_dropship_wallet_reconciliation_report(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.get_dropship_wallet_reconciliation_report(bigint) TO service_role;