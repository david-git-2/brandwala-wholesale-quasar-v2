CREATE FUNCTION public.get_koba_customers_list (
  p_tenant_id bigint,
  p_search    text    DEFAULT NULL::text,
  p_limit     integer DEFAULT 50,
  p_offset    integer DEFAULT 0
)
  RETURNS TABLE (
    phone           text,
    name            text,
    district        text,
    thana           text,
    address         text,
    total_orders    bigint,
    total_spent     numeric,
    last_order_date timestamp with time zone
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  -- Access Control Check: Only tenant admin, staff, or superadmin can view analytics
  if not (
    public.is_superadmin()
    or exists (
      select 1
      from public.memberships m
      where lower(trim(m.email)) = public.current_user_email()
        and m.tenant_id = p_tenant_id
        and m.role in ('admin', 'staff')
        and m.is_active = true
    )
  ) then
    raise exception 'access denied';
  end if;

  return query
  with customer_phones as (
    select
      o.shipping_phone as cp_phone,
      count(o.id) as cp_total_orders,
      coalesce(sum(o.subtotal_gbp), 0) as cp_total_spent,
      max(o.created_at) as cp_last_order_date,
      max(o.id) as cp_last_order_id
    from public.koba_orders o
    where o.tenant_id = p_tenant_id
      and o.shipping_phone is not null
      and o.shipping_phone <> ''
      and (
        p_search is null 
        or p_search = '' 
        or o.shipping_phone iLike '%' || trim(p_search) || '%' 
        or o.shipping_name iLike '%' || trim(p_search) || '%'
      )
    group by o.shipping_phone
  )
  select
    cp.cp_phone as phone,
    o.shipping_name as name,
    o.shipping_district as district,
    o.shipping_thana as thana,
    o.shipping_address as address,
    cp.cp_total_orders as total_orders,
    cp.cp_total_spent::numeric(12,2) as total_spent,
    cp.cp_last_order_date as last_order_date
  from customer_phones cp
  join public.koba_orders o on o.id = cp.cp_last_order_id
  order by cp.cp_last_order_date desc
  limit p_limit offset p_offset;
end;
$function$;

GRANT ALL ON FUNCTION public.get_koba_customers_list(bigint, text, integer, integer) TO anon;

GRANT ALL ON FUNCTION public.get_koba_customers_list(bigint, text, integer, integer) TO authenticated;

GRANT ALL ON FUNCTION public.get_koba_customers_list(bigint, text, integer, integer) TO service_role;