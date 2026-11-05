CREATE FUNCTION public.list_tenants_for_superadmin()
  RETURNS TABLE (
    id                 bigint,
    name               text,
    slug               text,
    public_domain      text,
    is_active          boolean,
    parent_id          bigint,
    preference         jsonb,
    base_currency_code text,
    created_at         timestamp with time zone,
    updated_at         timestamp with time zone
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  if not public.is_superadmin() then
    return;
  end if;

  return query
  select
    t.id,
    t.name,
    t.slug,
    t.public_domain,
    t.is_active,
    t.parent_id,
    t.preference,
    t.base_currency_code,
    t.created_at,
    t.updated_at
  from public.tenants t
  order by t.id asc;
end;
$function$;

GRANT ALL ON FUNCTION public.list_tenants_for_superadmin() TO anon;

GRANT ALL ON FUNCTION public.list_tenants_for_superadmin() TO authenticated;

GRANT ALL ON FUNCTION public.list_tenants_for_superadmin() TO service_role;