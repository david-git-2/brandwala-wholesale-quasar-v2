CREATE FUNCTION public.current_customer_group_id (
  p_tenant_id bigint
)
  RETURNS bigint
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  with candidates as (
    select distinct cg.id
    from public.customer_groups cg
    join public.customer_group_members cgm on cgm.customer_group_id = cg.id
    where p_tenant_id is not null
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
  )
  select c.id
  from candidates c
  where c.id = public.current_selected_customer_group_id()
     or (
       public.current_selected_customer_group_id() is null
       and (select count(*) from candidates) = 1
     )
  limit 1;
$function$;

GRANT ALL ON FUNCTION public.current_customer_group_id(bigint) TO anon;

GRANT ALL ON FUNCTION public.current_customer_group_id(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.current_customer_group_id(bigint) TO service_role;