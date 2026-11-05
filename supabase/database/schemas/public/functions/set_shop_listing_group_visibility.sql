CREATE FUNCTION public.set_shop_listing_group_visibility (
  p_shop_id           bigint,
  p_customer_group_id bigint,
  p_listing_id        bigint,
  p_visible           boolean
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_tenant_id bigint;
  v_shop_type public.shop_type_enum;
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
    raise exception 'listing visibility is only for dropship shops';
  end if;

  if not exists (
    select 1
    from public.shop_product_listings l
    where l.id = p_listing_id
      and l.shop_id = p_shop_id
  ) then
    raise exception 'listing not found on this shop';
  end if;

  if coalesce(p_visible, true) then
    delete from public.shop_listing_group_hides
    where listing_id = p_listing_id
      and customer_group_id = p_customer_group_id;
  else
    insert into public.shop_listing_group_hides (shop_id, listing_id, customer_group_id)
    values (p_shop_id, p_listing_id, p_customer_group_id)
    on conflict (listing_id, customer_group_id) do nothing;
  end if;

  return jsonb_build_object('success', true, 'listing_id', p_listing_id, 'is_visible', coalesce(p_visible, true));
end;
$function$;

GRANT ALL ON FUNCTION public.set_shop_listing_group_visibility(bigint, bigint, bigint, boolean) TO anon;

GRANT ALL ON FUNCTION public.set_shop_listing_group_visibility(bigint, bigint, bigint, boolean) TO authenticated;

GRANT ALL ON FUNCTION public.set_shop_listing_group_visibility(bigint, bigint, bigint, boolean) TO service_role;