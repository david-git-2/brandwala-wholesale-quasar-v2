CREATE FUNCTION public.fetch_customer_shop_categories (
  p_tenant_id bigint
)
  RETURNS TABLE (
    name  text,
    count bigint
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_parent_tenant_id bigint;
begin
  v_parent_tenant_id := public.resolve_parent_tenant_id(p_tenant_id);

  return query
  with accessible_shops as (
    select distinct s.id, s.shop_type, s.vendor_code, s.vendor_filters
    from public.shops s
    join public.shop_customer_group_access access on access.shop_id = s.id
    join public.customer_groups cg on cg.id = access.customer_group_id
    join public.customer_group_members cgm on cgm.customer_group_id = cg.id
    left join public.customer_group_shop_profiles profile
      on profile.customer_group_id = cg.id and profile.tenant_id = s.tenant_id
    where s.is_active = true
      and cg.is_active = true
      and cgm.is_active = true
      and lower(trim(cgm.email)) = public.current_user_email()
      and s.tenant_id = p_tenant_id
      and access.status = true
      and coalesce(profile.is_active, true) = true
      and coalesce(access.can_browse, profile.default_can_browse, false) = true
  ),
  vendor_products as (
    select distinct p.id, p.category
    from public.products p
    join accessible_shops s on s.shop_type = 'vendor_catalog'
    where p.is_available = true
      and p.parent_tenant_id = v_parent_tenant_id
      and (
        ((s.vendor_filters is null or jsonb_array_length(s.vendor_filters) = 0) and p.vendor_code = s.vendor_code)
        or
        (s.vendor_filters is not null and jsonb_array_length(s.vendor_filters) > 0 and exists (
          select 1 
          from jsonb_to_recordset(s.vendor_filters) as vf(vendor_code text, brands text[])
          where vf.vendor_code = p.vendor_code
            and (vf.brands is null or array_length(vf.brands, 1) is null or p.brand = any(vf.brands))
        ))
      )
  ),
  listing_products as (
    select distinct p.id, p.category
    from public.shop_product_listings l
    join accessible_shops s on s.id = l.shop_id and s.shop_type <> 'vendor_catalog'
    join public.products p on p.id = l.product_id
    where l.is_active = true
      and p.is_available = true
  ),
  combined_products as (
    select id, category from vendor_products
    union
    select id, category from listing_products
  )
  select 
    coalesce(nullif(trim(cp.category), ''), 'Uncategorized') as name,
    count(cp.id)::bigint as count
  from combined_products cp
  group by coalesce(nullif(trim(cp.category), ''), 'Uncategorized')
  order by count(cp.id) desc, name asc;
end;
$function$;

GRANT ALL ON FUNCTION public.fetch_customer_shop_categories(bigint) TO anon;

GRANT ALL ON FUNCTION public.fetch_customer_shop_categories(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.fetch_customer_shop_categories(bigint) TO service_role;