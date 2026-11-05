CREATE FUNCTION public.list_my_admin_tenants()
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
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  with owner_roots as (
    select m.tenant_id as root_id
    from public.memberships m
    where lower(trim(m.email)) = public.current_user_email()
      and m.role = 'owner'::public.app_role
      and m.is_active = true
  ),
  manager_desks as (
    select m.tenant_id as desk_id
    from public.memberships m
    where lower(trim(m.email)) = public.current_user_email()
      and m.role = 'manager'::public.app_role
      and m.is_active = true
  )
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
  where t.id in (select root_id from owner_roots)
     or t.parent_id in (select root_id from owner_roots)
     or t.id in (select desk_id from manager_desks)
  order by t.id asc;
$function$;

GRANT ALL ON FUNCTION public.list_my_admin_tenants() TO anon;

GRANT ALL ON FUNCTION public.list_my_admin_tenants() TO authenticated;

GRANT ALL ON FUNCTION public.list_my_admin_tenants() TO service_role;