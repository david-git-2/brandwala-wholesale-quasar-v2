CREATE FUNCTION public.get_koba_customer_profile (
  p_tenant_id bigint,
  p_phone     text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_latest_order_id bigint;
  v_latest_name text;
  v_latest_district text;
  v_latest_thana text;
  v_latest_address text;
  
  v_total_orders bigint;
  v_total_spent numeric(12,2);
  v_first_order_date timestamptz;
  v_last_order_date timestamptz;
  v_avg_days_between_orders numeric(10,2);
  
  v_brand_demand jsonb;
  v_top_products jsonb;
  v_order_history jsonb;
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

  -- Get overview stats
  select
    max(id) as last_order_id,
    count(id) as total_orders,
    coalesce(sum(subtotal_gbp), 0) as total_spent,
    min(created_at) as first_order_date,
    max(created_at) as last_order_date
  into
    v_latest_order_id,
    v_total_orders,
    v_total_spent,
    v_first_order_date,
    v_last_order_date
  from public.koba_orders
  where tenant_id = p_tenant_id
    and shipping_phone = p_phone;
    
  if v_total_orders = 0 or v_total_orders is null then
    return null;
  end if;
  
  -- Calculate average frequency (days between orders)
  if v_total_orders > 1 then
    v_avg_days_between_orders := (extract(epoch from (v_last_order_date - v_first_order_date)) / 86400.0) / (v_total_orders - 1);
  else
    v_avg_days_between_orders := null;
  end if;
  
  -- Get contact details from latest order
  select
    shipping_name,
    shipping_district,
    shipping_thana,
    shipping_address
  into
    v_latest_name,
    v_latest_district,
    v_latest_thana,
    v_latest_address
  from public.koba_orders
  where id = v_latest_order_id;
  
  -- Aggregate brand demand (Top 5 ordered brands)
  select coalesce(jsonb_agg(x), '[]'::jsonb)
  into v_brand_demand
  from (
    select
      coalesce(nullif(trim(oi.brand), ''), 'Unknown') as brand,
      count(distinct o.id) as order_count,
      sum(oi.quantity) as item_count
    from public.koba_orders o
    join public.koba_order_items oi on oi.order_id = o.id
    where o.tenant_id = p_tenant_id
      and o.shipping_phone = p_phone
    group by coalesce(nullif(trim(oi.brand), ''), 'Unknown')
    order by order_count desc, item_count desc
    limit 5
  ) x;
  
  -- Aggregate top products (Top 5 ordered products)
  select coalesce(jsonb_agg(y), '[]'::jsonb)
  into v_top_products
  from (
    select
      oi.product_id,
      oi.name,
      coalesce(nullif(trim(oi.brand), ''), 'Unknown') as brand,
      sum(oi.quantity) as total_quantity
    from public.koba_orders o
    join public.koba_order_items oi on oi.order_id = o.id
    where o.tenant_id = p_tenant_id
      and o.shipping_phone = p_phone
    group by oi.product_id, oi.name, oi.brand
    order by total_quantity desc
    limit 5
  ) y;
  
  -- Aggregate order history timeline
  select coalesce(jsonb_agg(z), '[]'::jsonb)
  into v_order_history
  from (
    select
      o.id as order_id,
      o.subtotal_gbp,
      o.net_order_commission,
      o.status,
      o.created_at
    from public.koba_orders o
    where o.tenant_id = p_tenant_id
      and o.shipping_phone = p_phone
    order by o.created_at desc
    limit 15
  ) z;
  
  -- Return consolidated JSON response
  return jsonb_build_object(
    'phone', p_phone,
    'name', v_latest_name,
    'district', v_latest_district,
    'thana', v_latest_thana,
    'address', v_latest_address,
    'total_orders', v_total_orders,
    'total_spent', v_total_spent,
    'first_order_date', v_first_order_date,
    'last_order_date', v_last_order_date,
    'avg_days_between_orders', v_avg_days_between_orders,
    'brand_demand', v_brand_demand,
    'top_products', v_top_products,
    'order_history', v_order_history
  );
end;
$function$;

GRANT ALL ON FUNCTION public.get_koba_customer_profile(bigint, text) TO anon;

GRANT ALL ON FUNCTION public.get_koba_customer_profile(bigint, text) TO authenticated;

GRANT ALL ON FUNCTION public.get_koba_customer_profile(bigint, text) TO service_role;