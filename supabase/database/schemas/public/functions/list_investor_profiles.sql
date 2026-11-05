CREATE FUNCTION public.list_investor_profiles (
  p_tenant_id bigint,
  p_limit     integer DEFAULT 50,
  p_offset    integer DEFAULT 0,
  p_search    text    DEFAULT NULL::text
)
  RETURNS TABLE (
    id                bigint,
    tenant_id         bigint,
    name              text,
    phone             text,
    email             text,
    address           text,
    is_active         boolean,
    currency_code     text,
    notes             text,
    created_at        timestamp with time zone,
    updated_at        timestamp with time zone,
    total_capital_in  numeric,
    total_withdrawn   numeric,
    deployed_capital  numeric,
    available_balance numeric,
    total_count       bigint
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_total_count bigint;
begin
  if not public.membership_has_module_action(p_tenant_id, 'investor_profiles', 'view') then
    raise exception 'not allowed';
  end if;

  select count(*) into v_total_count
  from public.investors i
  where i.tenant_id = p_tenant_id
    and (p_search is null or i.name ilike '%' || p_search || '%' or i.email ilike '%' || p_search || '%');

  return query
  select
    i.id,
    i.tenant_id,
    i.name,
    i.phone,
    i.email,
    i.address,
    i.is_active,
    i.currency_code,
    i.notes,
    i.created_at,
    i.updated_at,
    public.investor_uwl_flow_total(p_tenant_id, i.id, 'in') as total_capital_in,
    public.investor_uwl_flow_total(p_tenant_id, i.id, 'out') as total_withdrawn,
    coalesce((
      select sum(si.allocated_cost)
      from public.shipment_investments si
      where si.investor_id = i.id and si.status = 'active'
    ), 0.00)::numeric as deployed_capital,
    (
      coalesce((
        public.get_wallet_account_balances(p_tenant_id, 'investor', i.id, i.currency_code)
          ->> 'available_balance'
      )::numeric, 0.00)
      - coalesce((
        select sum(si.allocated_cost)
        from public.shipment_investments si
        where si.investor_id = i.id and si.status = 'active'
      ), 0.00)
    )::numeric as available_balance,
    v_total_count
  from public.investors i
  where i.tenant_id = p_tenant_id
    and (p_search is null or i.name ilike '%' || p_search || '%' or i.email ilike '%' || p_search || '%')
  order by i.name asc
  limit p_limit
  offset p_offset;
end;
$function$;

GRANT ALL ON FUNCTION public.list_investor_profiles(bigint, integer, integer, text) TO anon;

GRANT ALL ON FUNCTION public.list_investor_profiles(bigint, integer, integer, text) TO authenticated;

GRANT ALL ON FUNCTION public.list_investor_profiles(bigint, integer, integer, text) TO service_role;