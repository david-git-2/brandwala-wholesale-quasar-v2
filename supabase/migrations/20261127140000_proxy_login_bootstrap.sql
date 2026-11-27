-- Proxy portal: login access check and bootstrap context

CREATE OR REPLACE FUNCTION "public"."check_proxy_login_access"(
    "p_email" "text",
    "p_tenant_id" bigint DEFAULT NULL::bigint
) RETURNS TABLE(
    "has_match" boolean,
    "matched_role" "text",
    "member_id" bigint,
    "member_name" "text",
    "member_email" "text",
    "member_tenant_id" bigint,
    "people_group_id" bigint,
    "people_group_name" "text",
    "people_group_type" "text",
    "member_is_active" boolean,
    "people_group_is_active" boolean,
    "member_created_at" timestamp with time zone,
    "member_updated_at" timestamp with time zone
)
    LANGUAGE "plpgsql"
    STABLE
    SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_email text;
BEGIN
  v_email := lower(trim(coalesce(p_email, public.current_user_email(), '')));

  IF length(v_email) = 0 THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    true,
    m.role,
    m.id,
    coalesce(nullif(trim(m.name), ''), ''),
    lower(trim(m.email)),
    m.tenant_id,
    g.id,
    g.name,
    g.type,
    m.is_active,
    (g.deleted_at IS NULL),
    m.created_at,
    m.updated_at
  FROM public.pp_people_group_member m
  INNER JOIN public.pp_people_group g
    ON g.id = m.people_group_id
  INNER JOIN public.tenants t
    ON t.id = m.tenant_id
  WHERE lower(trim(m.email)) = v_email
    AND m.is_active = true
    AND m.deleted_at IS NULL
    AND g.deleted_at IS NULL
    AND t.is_active = true
    AND (p_tenant_id IS NULL OR m.tenant_id = p_tenant_id)
    AND EXISTS (
      SELECT 1
      FROM public.tenant_modules tm
      WHERE tm.tenant_id = m.tenant_id
        AND tm.module_key = 'proxy_purchase'
        AND tm.is_active = true
    )
  ORDER BY
    g.name ASC,
    g.id ASC,
    CASE m.role WHEN 'admin' THEN 1 WHEN 'staff' THEN 2 ELSE 99 END ASC,
    m.id ASC;
END;
$$;

ALTER FUNCTION "public"."check_proxy_login_access"("p_email" "text", "p_tenant_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."get_proxy_bootstrap_context"(
    "p_email" "text" DEFAULT NULL::"text",
    "p_tenant_id" bigint DEFAULT NULL::bigint,
    "p_people_group_member_id" bigint DEFAULT NULL::bigint
) RETURNS TABLE(
    "member_id" bigint,
    "member_name" "text",
    "member_email" "text",
    "member_role" "text",
    "member_is_active" boolean,
    "people_group_id" bigint,
    "people_group_name" "text",
    "people_group_type" "text",
    "people_group_is_active" boolean,
    "tenant_id" bigint,
    "tenant_name" "text",
    "tenant_slug" "text",
    "tenant_is_active" boolean,
    "active_module_keys" "text"[],
    "effective_grants" "jsonb",
    "tenant_role_id" bigint,
    "is_admin" boolean,
    "permission_version" bigint
)
    LANGUAGE "plpgsql"
    STABLE
    SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_email text;
  v_perm_version bigint;
BEGIN
  v_email := lower(trim(coalesce(p_email, public.current_user_email(), '')));

  IF length(v_email) = 0 OR p_tenant_id IS NULL OR p_people_group_member_id IS NULL THEN
    RETURN;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.tenant_modules tm
    WHERE tm.tenant_id = p_tenant_id
      AND tm.module_key = 'proxy_purchase'
      AND tm.is_active = true
  ) THEN
    RETURN;
  END IF;

  SELECT version INTO v_perm_version
  FROM public.tenant_permission_versions
  WHERE tenant_id = p_tenant_id;

  IF v_perm_version IS NULL THEN
    PERFORM public.bump_tenant_permission_version(p_tenant_id);
    v_perm_version := 1;
  END IF;

  RETURN QUERY
  SELECT
    m.id,
    coalesce(nullif(trim(m.name), ''), ''),
    lower(trim(m.email)),
    m.role,
    m.is_active,
    g.id,
    g.name,
    g.type,
    (g.deleted_at IS NULL),
    t.id,
    t.name,
    t.slug,
    t.is_active,
    ARRAY['proxy_purchase']::text[],
    jsonb_build_array(jsonb_build_object('module_key', 'proxy_purchase', 'action', 'view')),
    NULL::bigint,
    false,
    v_perm_version
  FROM public.pp_people_group_member m
  INNER JOIN public.pp_people_group g ON g.id = m.people_group_id
  INNER JOIN public.tenants t ON t.id = m.tenant_id
  WHERE m.id = p_people_group_member_id
    AND m.tenant_id = p_tenant_id
    AND lower(trim(m.email)) = v_email
    AND m.is_active = true
    AND m.deleted_at IS NULL
    AND g.deleted_at IS NULL
    AND t.is_active = true
  LIMIT 1;
END;
$$;

ALTER FUNCTION "public"."get_proxy_bootstrap_context"("p_email" "text", "p_tenant_id" bigint, "p_people_group_member_id" bigint) OWNER TO "postgres";

GRANT ALL ON FUNCTION "public"."check_proxy_login_access"("p_email" "text", "p_tenant_id" bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."check_proxy_login_access"("p_email" "text", "p_tenant_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."check_proxy_login_access"("p_email" "text", "p_tenant_id" bigint) TO "service_role";

GRANT ALL ON FUNCTION "public"."get_proxy_bootstrap_context"("p_email" "text", "p_tenant_id" bigint, "p_people_group_member_id" bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."get_proxy_bootstrap_context"("p_email" "text", "p_tenant_id" bigint, "p_people_group_member_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_proxy_bootstrap_context"("p_email" "text", "p_tenant_id" bigint, "p_people_group_member_id" bigint) TO "service_role";