CREATE FUNCTION public.customer_can_select_shop (
  p_shop_id   bigint,
  p_tenant_id bigint
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select exists (
    select 1
    from public.shop_customer_group_access access
    join public.customer_groups cg on cg.id = access.customer_group_id
    join public.customer_group_members cgm on cgm.customer_group_id = cg.id
    left join public.customer_group_shop_profiles profile
      on profile.customer_group_id = cg.id
     and profile.tenant_id = p_tenant_id
    where access.shop_id = p_shop_id
      and cg.is_active = true
      and cgm.is_active = true
      and lower(trim(cgm.email)) = public.current_user_email()
      and access.status = true
      and coalesce(profile.is_active, true) = true
      and coalesce(access.can_browse, profile.default_can_browse, false) = true
  );
$function$;

GRANT ALL ON FUNCTION public.customer_can_select_shop(bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.customer_can_select_shop(bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.customer_can_select_shop(bigint, bigint) TO service_role;