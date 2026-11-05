CREATE FUNCTION public.delete_tenant_for_superadmin (
  p_tenant_id bigint
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
  LANGUAGE sql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  with permission as (
    select public.is_superadmin() as allowed
  ),
  deleted as (
    delete from public.tenants as t
    using permission
    where allowed
      and t.id = p_tenant_id
    returning
      t.id,
      t.name,
      t.slug,
      t.public_domain,
      t.is_active,
      t.parent_id,
      t.preference,
      t.created_at,
      t.updated_at
  )
  select
    id,
    name,
    slug,
    public_domain,
    is_active,
    parent_id,
    preference,
    created_at,
    updated_at
  from deleted;
$function$;

GRANT ALL ON FUNCTION public.delete_tenant_for_superadmin(bigint) TO anon;

GRANT ALL ON FUNCTION public.delete_tenant_for_superadmin(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.delete_tenant_for_superadmin(bigint) TO service_role;