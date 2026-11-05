CREATE FUNCTION public.create_tenant_for_superadmin (
  p_name          text,
  p_slug          text,
  p_is_active     boolean DEFAULT true,
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
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_id bigint;
  v_name text;
  v_slug text;
  v_public_domain text;
  v_is_active boolean;
  v_parent_id bigint;
  v_preference jsonb;
  v_created_at timestamptz;
  v_updated_at timestamptz;
begin
  if not public.is_superadmin() then
    return;
  end if;

  insert into public.tenants (name, slug, public_domain, is_active, parent_id)
  values (
    trim(p_name),
    lower(trim(p_slug)),
    nullif(
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
    coalesce(p_is_active, true),
    p_parent_id
  )
  returning
    tenants.id,
    tenants.name,
    tenants.slug,
    tenants.public_domain,
    tenants.is_active,
    tenants.parent_id,
    tenants.preference,
    tenants.created_at,
    tenants.updated_at
  into
    v_id,
    v_name,
    v_slug,
    v_public_domain,
    v_is_active,
    v_parent_id,
    v_preference,
    v_created_at,
    v_updated_at;

  if v_parent_id is null then
    perform public.ensure_default_vendor(v_id);
    perform public.ensure_default_cargo_company(v_id);
  end if;

  return query
  select
    v_id,
    v_name,
    v_slug,
    v_public_domain,
    v_is_active,
    v_parent_id,
    v_preference,
    v_created_at,
    v_updated_at;
end;
$function$;

GRANT ALL ON FUNCTION public.create_tenant_for_superadmin(text, text, boolean, text, bigint) TO anon;

GRANT ALL ON FUNCTION public.create_tenant_for_superadmin(text, text, boolean, text, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.create_tenant_for_superadmin(text, text, boolean, text, bigint) TO service_role;