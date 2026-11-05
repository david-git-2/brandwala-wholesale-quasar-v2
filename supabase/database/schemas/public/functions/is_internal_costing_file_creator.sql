CREATE FUNCTION public.is_internal_costing_file_creator (
  p_tenant_id bigint,
  p_email     text
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select exists (
    select 1
    from public.memberships m
    where lower(trim(m.email)) = lower(trim(coalesce(p_email, '')))
      and m.is_active = true
      and (
        (m.tenant_id = p_tenant_id and m.role in ('admin', 'staff'))
        or (m.tenant_id is null and m.role = 'superadmin')
      )
  );
$function$;

GRANT ALL ON FUNCTION public.is_internal_costing_file_creator(bigint, text) TO anon;

GRANT ALL ON FUNCTION public.is_internal_costing_file_creator(bigint, text) TO authenticated;

GRANT ALL ON FUNCTION public.is_internal_costing_file_creator(bigint, text) TO service_role;