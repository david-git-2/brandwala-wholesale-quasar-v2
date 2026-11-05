CREATE FUNCTION public.list_investor_wallet_activity (
  p_tenant_id   bigint,
  p_investor_id bigint  DEFAULT NULL::bigint,
  p_limit       integer DEFAULT 50,
  p_offset      integer DEFAULT 0
)
  RETURNS TABLE (
    id               text,
    investor_id      bigint,
    amount           numeric,
    activity_date    date,
    method           public.investor_payment_method,
    transaction_type text,
    note             text,
    created_at       timestamp with time zone,
    total_count      bigint
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_total_count bigint;
begin
  if not (
    public.user_can_manage_parent_tenant(p_tenant_id)
    or (p_investor_id is not null and public.auth_investor_id() = p_investor_id)
  ) then
    raise exception 'not allowed';
  end if;

  select count(*) into v_total_count
  from public.cashbook_entries uwl
  inner join public.investors i on i.id = uwl.entity_id
  where i.tenant_id = p_tenant_id
    and uwl.entity_type = 'investor'
    and (p_investor_id is null or uwl.entity_id = p_investor_id)
    and coalesce(uwl.metadata->>'section', '') = 'investor_capital';

  return query
  select
    uwl.id::text,
    uwl.entity_id as investor_id,
    abs(uwl.amount)::numeric,
    uwl.created_at::date as activity_date,
    coalesce(nullif(uwl.metadata->>'method', ''), 'other')::public.investor_payment_method,
    coalesce(uwl.metadata->>'transaction_type', 'manual_adjustment'),
    coalesce(uwl.metadata->>'notes', uwl.metadata->>'note'),
    uwl.created_at,
    v_total_count
  from public.cashbook_entries uwl
  inner join public.investors i on i.id = uwl.entity_id
  where i.tenant_id = p_tenant_id
    and uwl.entity_type = 'investor'
    and (p_investor_id is null or uwl.entity_id = p_investor_id)
    and coalesce(uwl.metadata->>'section', '') = 'investor_capital'
  order by uwl.created_at desc
  limit p_limit
  offset p_offset;
end;
$function$;

GRANT ALL ON FUNCTION public.list_investor_wallet_activity(bigint, bigint, integer, integer) TO anon;

GRANT ALL ON FUNCTION public.list_investor_wallet_activity(bigint, bigint, integer, integer) TO authenticated;

GRANT ALL ON FUNCTION public.list_investor_wallet_activity(bigint, bigint, integer, integer) TO service_role;