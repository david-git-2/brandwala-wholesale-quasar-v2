CREATE FUNCTION public.get_app_login_bundle (
  p_email                 text DEFAULT NULL::text,
  p_requested_tenant_slug text DEFAULT NULL::text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_email text;
  v_slug text;
  v_login record;
  v_tenants jsonb := '[]'::jsonb;
  v_membership_tenant_id bigint;
  v_membership_parent_id bigint;
  v_workspace_tenant_id bigint;
  v_bootstrap jsonb;
  v_membership_id bigint;
begin
  v_email := lower(trim(coalesce(p_email, public.current_user_email(), '')));
  v_slug := lower(trim(coalesce(p_requested_tenant_slug, '')));

  select *
  into v_login
  from public.check_login_membership(v_email, 'app')
  limit 1;

  if not coalesce(v_login.has_match, false) then
    return jsonb_build_object('has_match', false);
  end if;

  select coalesce(jsonb_agg(to_jsonb(t) order by t.id), '[]'::jsonb)
  into v_tenants
  from public.list_tenants_by_membership(null::bigint, v_email, null::public.app_role) t;

  if coalesce(jsonb_array_length(v_tenants), 0) = 0 then
    return jsonb_build_object('has_match', false);
  end if;

  if v_slug <> '' then
    select t.id, t.parent_id
    into v_membership_tenant_id, v_membership_parent_id
    from public.list_tenants_by_membership(null::bigint, v_email, null::public.app_role) t
    where lower(trim(t.slug)) = v_slug
    limit 1;

    if v_membership_tenant_id is null then
      return jsonb_build_object(
        'has_match', true,
        'error_code', 'invalid_tenant',
        'login', jsonb_build_object(
          'matched_role', v_login.matched_role,
          'member_id', v_login.member_id,
          'member_email', v_login.member_email,
          'member_tenant_id', v_login.member_tenant_id,
          'member_is_active', v_login.member_is_active,
          'member_created_at', v_login.member_created_at,
          'member_updated_at', v_login.member_updated_at
        ),
        'tenants', v_tenants
      );
    end if;
  else
    select t.id, t.parent_id
    into v_membership_tenant_id, v_membership_parent_id
    from public.list_tenants_by_membership(null::bigint, v_email, null::public.app_role) t
    where t.parent_id is null
    order by t.id
    limit 1;
  end if;

  if v_membership_tenant_id is null then
    return jsonb_build_object(
      'has_match', true,
      'error_code', 'no_tenant_access',
      'login', jsonb_build_object(
        'matched_role', v_login.matched_role,
        'member_id', v_login.member_id,
        'member_email', v_login.member_email,
        'member_tenant_id', v_login.member_tenant_id,
        'member_is_active', v_login.member_is_active,
        'member_created_at', v_login.member_created_at,
        'member_updated_at', v_login.member_updated_at
      ),
      'tenants', v_tenants
    );
  end if;

  if v_membership_parent_id is null then
    v_workspace_tenant_id := v_membership_tenant_id;
  else
    select t.id
    into v_workspace_tenant_id
    from public.list_tenants_by_membership(null::bigint, v_email, null::public.app_role) t
    where t.id = v_membership_parent_id
    limit 1;
  end if;

  if v_workspace_tenant_id is null then
    return jsonb_build_object(
      'has_match', true,
      'error_code', 'no_workspace',
      'tenants', v_tenants
    );
  end if;

  v_membership_id := case
    when v_login.member_tenant_id = v_workspace_tenant_id then v_login.member_id
    else null
  end;

  select to_jsonb(b)
  into v_bootstrap
  from public.get_app_bootstrap_context(v_email, v_workspace_tenant_id, v_membership_id) b
  limit 1;

  if v_bootstrap is null or (v_bootstrap->>'member_id') is null then
    return jsonb_build_object(
      'has_match', true,
      'error_code', 'bootstrap_failed',
      'tenants', v_tenants,
      'workspace_tenant_id', v_workspace_tenant_id
    );
  end if;

  return jsonb_build_object(
    'has_match', true,
    'login', jsonb_build_object(
      'matched_role', v_login.matched_role,
      'member_id', v_login.member_id,
      'member_email', v_login.member_email,
      'member_tenant_id', v_login.member_tenant_id,
      'member_is_active', v_login.member_is_active,
      'member_created_at', v_login.member_created_at,
      'member_updated_at', v_login.member_updated_at
    ),
    'tenants', v_tenants,
    'workspace_tenant_id', v_workspace_tenant_id,
    'bootstrap', v_bootstrap
  );
end;
$function$;

GRANT ALL ON FUNCTION public.get_app_login_bundle(text, text) TO anon;

GRANT ALL ON FUNCTION public.get_app_login_bundle(text, text) TO authenticated;

GRANT ALL ON FUNCTION public.get_app_login_bundle(text, text) TO service_role;