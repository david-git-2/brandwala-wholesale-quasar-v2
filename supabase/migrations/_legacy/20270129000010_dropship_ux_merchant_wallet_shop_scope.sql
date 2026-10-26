-- Shop-scoped merchant dropship wallet summary + ledger (read-only)

begin;

create or replace function public.get_my_dropship_wallet_summary()
returns table (
  billing_profile_id bigint,
  available_balance numeric,
  pending_balance numeric,
  locked_balance numeric,
  currency text
)
language plpgsql
security definer
set search_path = public
stable
as $$
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

  v_bp_id := public.resolve_billing_profile_for_customer_group(v_tenant_id, v_group_id);
  if v_bp_id is null then
    raise exception 'No billing profile linked for your customer group';
  end if;

  select coalesce(sum(
    case when u.type = 'credit' then u.amount else -u.amount end
  ), 0)
  into v_available
  from public.universal_wallet_ledger u
  where u.tenant_id = v_tenant_id
    and u.entity_id = v_bp_id
    and u.entity_type in ('middleman', 'customer');

  -- Pending: profit credits on delivered orders not yet remitted / unsettled (best-effort)
  select coalesce(sum(u.amount), 0)
  into v_pending
  from public.universal_wallet_ledger u
  join public.shop_orders o
    on o.id::text = u.source_id
   and o.tenant_id = u.tenant_id
  where u.tenant_id = v_tenant_id
    and u.entity_id = v_bp_id
    and u.entity_type in ('middleman', 'customer')
    and u.type = 'credit'
    and coalesce(u.metadata->>'transaction_type', '') = 'dropship_profit'
    and coalesce(o.payout_settlement_status, 'unpaid') in ('unpaid', 'partial')
    and o.status::text in ('delivered', 'payment_received', 'shipped', 'ready_for_pickup');

  -- Locked: remittance escrow style — delivered but courier not remitted
  select coalesce(sum(greatest(coalesce(o.cod_collect_amount, 0), 0)), 0)
  into v_locked
  from public.shop_orders o
  where o.tenant_id = v_tenant_id
    and o.billing_profile_id = v_bp_id
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
$$;

create or replace function public.list_my_dropship_wallet_ledger(
  p_limit integer default 50,
  p_offset integer default 0
)
returns table (
  id text,
  created_at timestamptz,
  transaction_type text,
  amount numeric,
  balance_after numeric,
  source_id text,
  order_id bigint,
  note text
)
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_email text := public.current_user_email();
  v_tenant_id bigint;
  v_group_id bigint;
  v_bp_id bigint;
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

  if v_tenant_id is null then
    raise exception 'No active customer group membership';
  end if;

  v_bp_id := public.resolve_billing_profile_for_customer_group(v_tenant_id, v_group_id);
  if v_bp_id is null then
    raise exception 'No billing profile linked for your customer group';
  end if;

  return query
  select
    u.id::text,
    u.created_at,
    coalesce(u.metadata->>'transaction_type', u.metadata->>'purpose', u.type)::text as transaction_type,
    case when u.type = 'debit' then -u.amount else u.amount end,
    u.balance_after,
    u.source_id,
    case
      when u.source_type = 'shop_order' and u.source_id ~ '^[0-9]+$' then u.source_id::bigint
      else null
    end as order_id,
    coalesce(u.metadata->>'notes', u.metadata->>'note', '')::text as note
  from public.universal_wallet_ledger u
  where u.tenant_id = v_tenant_id
    and u.entity_id = v_bp_id
    and u.entity_type in ('middleman', 'customer')
  order by u.created_at desc, u.id desc
  limit greatest(coalesce(p_limit, 50), 1)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

grant execute on function public.get_my_dropship_wallet_summary() to authenticated;
grant execute on function public.list_my_dropship_wallet_ledger(integer, integer) to authenticated;

commit;
