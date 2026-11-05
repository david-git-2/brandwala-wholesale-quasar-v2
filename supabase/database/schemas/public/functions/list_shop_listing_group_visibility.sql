CREATE FUNCTION public.list_shop_listing_group_visibility (
  p_shop_id           bigint,
  p_customer_group_id bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_tenant_id bigint;
  v_shop_type public.shop_type_enum;
  v_data jsonb;
begin
  select s.tenant_id, s.shop_type
  into v_tenant_id, v_shop_type
  from public.shops s
  where s.id = p_shop_id
    and s.deleted_at is null;

  if v_tenant_id is null then
    raise exception 'shop not found';
  end if;

  if not public.user_can_manage_shop_tenant(v_tenant_id)
     and not public.user_can_manage_shop_tenant(public.resolve_parent_tenant_id(v_tenant_id))
     and not public.is_superadmin() then
    raise exception 'not allowed';
  end if;

  if v_shop_type <> 'dropship' then
    return jsonb_build_object('data', '[]'::jsonb);
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'listing_id', l.id,
        'product_id', p.id,
        'product_name', p.name,
        'product_image_url', p.image_url,
        'is_visible', h.listing_id is null
      )
      order by p.name asc, l.id asc
    ),
    '[]'::jsonb
  )
  into v_data
  from public.shop_product_listings l
  join public.products p on p.id = l.product_id
  left join public.shop_listing_group_hides h
    on h.listing_id = l.id
   and h.customer_group_id = p_customer_group_id
  where l.shop_id = p_shop_id
    and l.is_active = true;

  return jsonb_build_object('data', v_data);
end;
$function$;

GRANT ALL ON FUNCTION public.list_shop_listing_group_visibility(bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.list_shop_listing_group_visibility(bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.list_shop_listing_group_visibility(bigint, bigint) TO service_role;