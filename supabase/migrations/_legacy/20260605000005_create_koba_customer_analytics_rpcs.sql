begin;

-- 1. Create optimized B-tree index for lookup and analytics grouping
create index if not exists koba_orders_tenant_phone_idx 
on public.koba_orders(tenant_id, shipping_phone) 
where shipping_phone is not null and shipping_phone <> '';

-- 2. Create customer list function
create or replace function public.get_koba_customers_list(
  p_tenant_id bigint,
  p_search text default null,
  p_limit int default 50,
  p_offset int default 0
)
returns table(
  phone text,
  name text,
  district text,
  thana text,
  address text,
  total_orders bigint,
  total_spent numeric(12,2),
  last_order_date timestamptz
)
language plpgsql
security definer
set search_path = public
stable
as $$
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
$$;

-- 3. Create customer profile details and analytics function
create or replace function public.get_koba_customer_profile(
  p_tenant_id bigint,
  p_phone text
)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
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
$$;

-- 4. Grant execution permissions
grant execute on function public.get_koba_customers_list(bigint, text, int, int) to authenticated, service_role;
grant execute on function public.get_koba_customer_profile(bigint, text) to authenticated, service_role;

commit;
