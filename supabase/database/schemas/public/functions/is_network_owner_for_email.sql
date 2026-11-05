CREATE FUNCTION public.is_network_owner_for_email (
  p_email     text,
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
    from public.memberships m
    where m.tenant_id = public.resolve_parent_tenant_id(p_tenant_id)
      and lower(trim(m.email)) = lower(trim(coalesce(p_email, '')))
      and m.role = 'owner'::public.app_role
      and m.is_active = true
  );
$function$;

GRANT ALL ON FUNCTION public.is_network_owner_for_email(text, bigint) TO anon;

GRANT ALL ON FUNCTION public.is_network_owner_for_email(text, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.is_network_owner_for_email(text, bigint) TO service_role;