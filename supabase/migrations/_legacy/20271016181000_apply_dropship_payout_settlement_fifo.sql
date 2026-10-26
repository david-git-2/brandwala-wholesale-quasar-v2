-- Recreate after BP3 dropped billing_profile_id RPC signatures (20271012250000).
CREATE OR REPLACE FUNCTION "public"."apply_dropship_payout_settlement_fifo"("p_tenant_id" bigint, "p_profile_id" bigint, "p_amount" numeric) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_remaining numeric := greatest(coalesce(p_amount, 0), 0);
  v_parent_tenant_id bigint;
  r record;
  v_hold numeric;
  v_paid numeric;
  v_outstanding numeric;
begin
  if v_remaining <= 0 then
    return;
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(p_tenant_id);

  for r in
    select o.id
    from public.shop_orders o
    where o.profile_id = p_profile_id
      and o.shop_type_snapshot = 'dropship'
      and o.global_invoice_id is not null
      and coalesce(o.payout_settlement_status, 'unpaid') in ('unpaid', 'partial')
      and (
        o.tenant_id = p_tenant_id
        or o.parent_tenant_id = v_parent_tenant_id
        or o.tenant_id = v_parent_tenant_id
      )
    order by o.created_at asc, o.id asc
  loop
    exit when v_remaining <= 0;

    select coalesce(sum(u.amount), 0)
    into v_hold
    from public.cashbook_entries u
    where u.parent_tenant_id = v_parent_tenant_id
      and u.source_type = 'shop_order'
      and u.source_id = r.id::text
      and u.entity_type in ('middleman', 'customer')
      and u.type = 'credit'
      and coalesce(u.metadata->>'transaction_type', '') = 'dropship_profit';

    select coalesce(sum(u.amount), 0)
    into v_paid
    from public.cashbook_entries u
    where u.parent_tenant_id = v_parent_tenant_id
      and u.entity_type in ('middleman', 'customer')
      and u.entity_id = p_profile_id
      and u.type = 'debit'
      and coalesce(u.metadata->>'transaction_type', '') = 'profit_paid_out'
      and coalesce(u.metadata->>'shop_order_id', u.metadata->>'order_id', '') = r.id::text;

    v_outstanding := greatest(v_hold - v_paid, 0);

    if v_outstanding <= 0 then
      continue;
    end if;

    if v_remaining >= v_outstanding then
      update public.shop_orders
      set payout_settlement_status = 'paid',
          updated_at = now()
      where id = r.id;
      v_remaining := v_remaining - v_outstanding;
    else
      update public.shop_orders
      set payout_settlement_status = 'partial',
          updated_at = now()
      where id = r.id;
      v_remaining := 0;
    end if;
  end loop;
end;
$$;

GRANT EXECUTE ON FUNCTION public.apply_dropship_payout_settlement_fifo(bigint, bigint, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.apply_dropship_payout_settlement_fifo(bigint, bigint, numeric) TO service_role;
