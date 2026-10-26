CREATE OR REPLACE FUNCTION "public"."get_app_login_bundle"("p_email" "text" DEFAULT NULL::"text", "p_requested_tenant_slug" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;


ALTER FUNCTION "public"."get_app_login_bundle"("p_email" "text", "p_requested_tenant_slug" "text") OWNER TO "postgres";

GRANT ALL ON FUNCTION public.get_app_login_bundle(text, text) TO authenticated;

CREATE OR REPLACE FUNCTION "public"."get_app_dashboard_bundle"("p_tenant_id" bigint, "p_parent_tenant_ids" bigint[] DEFAULT NULL::bigint[]) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_proc jsonb := NULL;
  v_shop jsonb := NULL;
  v_investor jsonb := NULL;
  v_children jsonb := '[]'::jsonb;
  v_parent_ids bigint[];
BEGIN
  IF p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'p_tenant_id is required';
  END IF;

  IF NOT (
    public.is_superadmin()
    OR public.has_active_tenant_membership(p_tenant_id)
    OR public.user_can_manage_parent_tenant(public.resolve_parent_tenant_id(p_tenant_id))
  ) THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  IF public.membership_has_module_action(p_tenant_id, 'global_stock', 'view') THEN
    v_proc := public.get_procurement_dashboard_metrics(p_tenant_id);
  END IF;

  IF public.membership_has_module_action(p_tenant_id, 'shop_order', 'view') THEN
    v_shop := public.get_shop_order_dashboard_metrics(p_tenant_id);
  END IF;

  IF public.membership_has_module_action(p_tenant_id, 'investor_capital_ledger', 'view') THEN
    v_investor := public.get_staff_investor_capital_metrics(p_tenant_id);
  END IF;

  v_parent_ids := coalesce(p_parent_tenant_ids, ARRAY[]::bigint[]);
  IF cardinality(v_parent_ids) > 0 THEN
    SELECT coalesce(
      jsonb_agg(
        jsonb_build_object('id', c.id, 'parent_id', c.parent_id, 'name', c.name)
        ORDER BY c.parent_id, c.id
      ),
      '[]'::jsonb
    )
    INTO v_children
    FROM public.list_child_tenant_refs(v_parent_ids) AS c;
  END IF;

  RETURN jsonb_build_object(
    'refreshed_at', to_jsonb(now() AT TIME ZONE 'utc'),
    'procurement', v_proc,
    'shop_order', v_shop,
    'investor_capital', v_investor,
    'child_tenant_refs', v_children
  );
END;
$$;


ALTER FUNCTION "public"."get_app_dashboard_bundle"("p_tenant_id" bigint, "p_parent_tenant_ids" bigint[]) OWNER TO "postgres";
