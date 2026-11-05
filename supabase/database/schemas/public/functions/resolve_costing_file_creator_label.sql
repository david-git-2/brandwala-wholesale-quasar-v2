CREATE FUNCTION public.resolve_costing_file_creator_label (
  p_tenant_id         bigint,
  p_customer_group_id bigint,
  p_created_by_email  text
)
  RETURNS text
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select case
    when exists (
      select 1
      from public.memberships m
      where lower(trim(m.email)) = lower(trim(coalesce(p_created_by_email, '')))
        and m.is_active = true
        and (
          (m.tenant_id = p_tenant_id and m.role = 'admin')
          or (m.tenant_id is null and m.role = 'superadmin')
        )
    ) then 'admin'
    when exists (
      select 1
      from public.memberships m
      where lower(trim(m.email)) = lower(trim(coalesce(p_created_by_email, '')))
        and m.is_active = true
        and m.tenant_id = p_tenant_id
        and m.role = 'staff'
    ) then 'staff'
    else coalesce(
      (
        select cg.name
        from public.customer_group_members cgm
        inner join public.customer_groups cg
          on cg.id = cgm.customer_group_id
        where lower(trim(cgm.email)) = lower(trim(coalesce(p_created_by_email, '')))
          and cgm.is_active = true
          and cg.is_active = true
          and cgm.customer_group_id = p_customer_group_id
        limit 1
      ),
      'Unknown'
    )
  end;
$function$;

GRANT ALL ON FUNCTION public.resolve_costing_file_creator_label(bigint, bigint, text) TO anon;

GRANT ALL ON FUNCTION public.resolve_costing_file_creator_label(bigint, bigint, text) TO authenticated;

GRANT ALL ON FUNCTION public.resolve_costing_file_creator_label(bigint, bigint, text) TO service_role;