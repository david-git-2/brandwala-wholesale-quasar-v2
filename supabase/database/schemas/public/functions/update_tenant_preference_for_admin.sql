CREATE FUNCTION public.update_tenant_preference_for_admin (
  p_tenant_id  bigint,
  p_preference jsonb
)
  RETURNS TABLE (
    id            bigint,
    name          text,
    slug          text,
    public_domain text,
    is_active     boolean,
    parent_id     bigint,
    preference    jsonb,
    created_at    timestamp with time zone,
    updated_at    timestamp with time zone
  )
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  if not (
    public.is_superadmin()
    or public.is_tenant_admin(p_tenant_id)
  ) then
    return;
  end if;

  if jsonb_typeof(p_preference) is distinct from 'object' then
    raise exception 'Tenant preference must be a JSON object';
  end if;

  return query
  update public.tenants as t
  set preference = p_preference
  where t.id = p_tenant_id
  returning
    t.id,
    t.name,
    t.slug,
    t.public_domain,
    t.is_active,
    t.parent_id,
    t.preference,
    t.created_at,
    t.updated_at;
end;
$function$;

GRANT ALL ON FUNCTION public.update_tenant_preference_for_admin(bigint, jsonb) TO anon;

GRANT ALL ON FUNCTION public.update_tenant_preference_for_admin(bigint, jsonb) TO authenticated;

GRANT ALL ON FUNCTION public.update_tenant_preference_for_admin(bigint, jsonb) TO service_role;