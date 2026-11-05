CREATE FUNCTION public.update_tenant_for_superadmin (
  p_tenant_id     bigint,
  p_name          text,
  p_slug          text,
  p_is_active     boolean,
  p_public_domain text    DEFAULT NULL::text,
  p_parent_id     bigint  DEFAULT NULL::bigint
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
  updated as (
    update public.tenants as t
    set
      name = trim(p_name),
      slug = lower(trim(p_slug)),
      public_domain = nullif(
        regexp_replace(
          lower(
            trim(
              split_part(
                regexp_replace(coalesce(p_public_domain, ''), '^https?://', '', 'i'),
                '/',
                1
              )
            )
          ),
          ':\d+$',
          ''
        ),
        ''
      ),
      is_active = coalesce(p_is_active, true),
      parent_id = p_parent_id
    from permission
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
  from updated;
$function$;

GRANT ALL ON FUNCTION public.update_tenant_for_superadmin(bigint, text, text, boolean, text, bigint) TO anon;

GRANT ALL ON FUNCTION public.update_tenant_for_superadmin(bigint, text, text, boolean, text, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.update_tenant_for_superadmin(bigint, text, text, boolean, text, bigint) TO service_role;