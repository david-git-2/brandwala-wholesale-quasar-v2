CREATE FUNCTION public.list_my_dropship_wallet_ledger (
  p_limit  integer DEFAULT 50,
  p_offset integer DEFAULT 0
)
  RETURNS TABLE (
    id               text,
    created_at       timestamp with time zone,
    transaction_type text,
    amount           numeric,
    balance_after    numeric,
    source_id        text,
    order_id         bigint,
    note             text
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
  from public.cashbook_entries u
  where u.tenant_id = v_tenant_id
    and u.entity_id = v_bp_id
    and u.entity_type in ('middleman', 'customer')
  order by u.created_at desc, u.id desc
  limit greatest(coalesce(p_limit, 50), 1)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$function$;

GRANT ALL ON FUNCTION public.list_my_dropship_wallet_ledger(integer, integer) TO anon;

GRANT ALL ON FUNCTION public.list_my_dropship_wallet_ledger(integer, integer) TO authenticated;

GRANT ALL ON FUNCTION public.list_my_dropship_wallet_ledger(integer, integer) TO service_role;