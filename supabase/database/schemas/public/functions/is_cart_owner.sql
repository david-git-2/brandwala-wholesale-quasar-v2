CREATE FUNCTION public.is_cart_owner (
  p_customer_group_id bigint,
  p_tenant_id         bigint
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public', 'auth'
  AS $function$
  select exists (
    select 1
    from public.customer_groups cg
    join public.customer_group_members cgm on cgm.customer_group_id = cg.id
    where p_customer_group_id is not null
      and p_tenant_id is not null
      and cg.id = p_customer_group_id
      and cg.is_active = true
      and cg.deleted_at is null
      and cgm.is_active = true
      and lower(trim(cgm.email)) = public.current_user_email()
      and coalesce(cg.parent_tenant_id, cg.tenant_id) = public.resolve_parent_tenant_id(p_tenant_id)
      and (
        p_tenant_id = coalesce(cg.parent_tenant_id, cg.tenant_id)
        or exists (
          select 1
          from public.shop_customer_group_access scga
          inner join public.shops s on s.id = scga.shop_id
          where scga.customer_group_id = cg.id
            and scga.status = true
            and s.tenant_id = p_tenant_id
            and s.is_active = true
            and s.deleted_at is null
        )
      )
  );
$function$;

GRANT ALL ON FUNCTION public.is_cart_owner(bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.is_cart_owner(bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.is_cart_owner(bigint, bigint) TO service_role;