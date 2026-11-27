-- Proxy purchase people group RPCs

CREATE OR REPLACE FUNCTION "public"."list_pp_people_groups"(
    "p_tenant_id" bigint,
    "p_type" "text"
) RETURNS "jsonb"
    LANGUAGE "plpgsql"
    STABLE
    SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_type text := lower(trim(coalesce(p_type, '')));
BEGIN
  IF NOT "public"."has_active_tenant_membership"("p_tenant_id") THEN
    RAISE EXCEPTION 'Not allowed for tenant %', "p_tenant_id" USING ERRCODE = '42501';
  END IF;

  IF v_type NOT IN ('customer', 'supplier') THEN
    RAISE EXCEPTION 'Invalid people group type: %', p_type USING ERRCODE = '22023';
  END IF;

  RETURN (
    SELECT COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'id', g.id,
          'tenant_id', g.tenant_id,
          'name', g.name,
          'type', g.type,
          'member_count', (
            SELECT count(*)::bigint
            FROM public.pp_people_group_member m
            WHERE m.people_group_id = g.id
              AND m.deleted_at IS NULL
          ),
          'created_at', g.created_at
        )
        ORDER BY g.name ASC, g.id ASC
      ),
      '[]'::jsonb
    )
    FROM public.pp_people_group g
    WHERE g.tenant_id = p_tenant_id
      AND g.type = v_type
      AND g.deleted_at IS NULL
  );
END;
$$;

ALTER FUNCTION "public"."list_pp_people_groups"("p_tenant_id" bigint, "p_type" "text") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."create_pp_people_group"(
    "p_tenant_id" bigint,
    "p_name" "text",
    "p_type" "text"
) RETURNS "jsonb"
    LANGUAGE "plpgsql"
    SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_name text := trim(coalesce(p_name, ''));
  v_type text := lower(trim(coalesce(p_type, '')));
  v_row public.pp_people_group%ROWTYPE;
BEGIN
  IF NOT "public"."has_active_tenant_membership"("p_tenant_id") THEN
    RAISE EXCEPTION 'Not allowed for tenant %', "p_tenant_id" USING ERRCODE = '42501';
  END IF;

  IF length(v_name) = 0 THEN
    RAISE EXCEPTION 'Group name is required' USING ERRCODE = '22023';
  END IF;

  IF v_type NOT IN ('customer', 'supplier') THEN
    RAISE EXCEPTION 'Invalid people group type: %', p_type USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.pp_people_group (tenant_id, name, type)
  VALUES (p_tenant_id, v_name, v_type)
  RETURNING * INTO v_row;

  RETURN jsonb_build_object(
    'id', v_row.id,
    'tenant_id', v_row.tenant_id,
    'name', v_row.name,
    'type', v_row.type,
    'member_count', 0::bigint,
    'created_at', v_row.created_at
  );
END;
$$;

ALTER FUNCTION "public"."create_pp_people_group"("p_tenant_id" bigint, "p_name" "text", "p_type" "text") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."list_pp_people_group_members"(
    "p_tenant_id" bigint,
    "p_people_group_id" bigint
) RETURNS "jsonb"
    LANGUAGE "plpgsql"
    STABLE
    SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  IF NOT "public"."has_active_tenant_membership"("p_tenant_id") THEN
    RAISE EXCEPTION 'Not allowed for tenant %', "p_tenant_id" USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.pp_people_group g
    WHERE g.id = p_people_group_id
      AND g.tenant_id = p_tenant_id
      AND g.deleted_at IS NULL
  ) THEN
    RAISE EXCEPTION 'People group not found' USING ERRCODE = 'P0002';
  END IF;

  RETURN (
    SELECT COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'id', m.id,
          'people_group_id', m.people_group_id,
          'name', m.name,
          'email', m.email,
          'role', m.role,
          'is_active', m.is_active,
          'created_at', m.created_at
        )
        ORDER BY m.name ASC, m.id ASC
      ),
      '[]'::jsonb
    )
    FROM public.pp_people_group_member m
    WHERE m.tenant_id = p_tenant_id
      AND m.people_group_id = p_people_group_id
      AND m.deleted_at IS NULL
  );
END;
$$;

ALTER FUNCTION "public"."list_pp_people_group_members"("p_tenant_id" bigint, "p_people_group_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."create_pp_people_group_member"(
    "p_tenant_id" bigint,
    "p_people_group_id" bigint,
    "p_name" "text",
    "p_email" "text",
    "p_role" "text"
) RETURNS "jsonb"
    LANGUAGE "plpgsql"
    SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_name text := trim(coalesce(p_name, ''));
  v_email text := lower(trim(coalesce(p_email, '')));
  v_role text := lower(trim(coalesce(p_role, '')));
  v_group public.pp_people_group%ROWTYPE;
  v_row public.pp_people_group_member%ROWTYPE;
BEGIN
  IF NOT "public"."has_active_tenant_membership"("p_tenant_id") THEN
    RAISE EXCEPTION 'Not allowed for tenant %', "p_tenant_id" USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_group
  FROM public.pp_people_group g
  WHERE g.id = p_people_group_id
    AND g.tenant_id = p_tenant_id
    AND g.deleted_at IS NULL;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'People group not found' USING ERRCODE = 'P0002';
  END IF;

  IF length(v_name) = 0 THEN
    RAISE EXCEPTION 'Member name is required' USING ERRCODE = '22023';
  END IF;

  IF length(v_email) = 0 THEN
    RAISE EXCEPTION 'Member email is required' USING ERRCODE = '22023';
  END IF;

  IF v_role NOT IN ('admin', 'staff') THEN
    RAISE EXCEPTION 'Invalid member role: %', p_role USING ERRCODE = '22023';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.pp_people_group_member m
    WHERE m.people_group_id = p_people_group_id
      AND lower(trim(m.email)) = v_email
      AND m.deleted_at IS NULL
  ) THEN
    RAISE EXCEPTION 'A member with this email already exists in the group' USING ERRCODE = '23505';
  END IF;

  INSERT INTO public.pp_people_group_member (
    tenant_id,
    people_group_id,
    name,
    email,
    role
  )
  VALUES (
    v_group.tenant_id,
    p_people_group_id,
    v_name,
    v_email,
    v_role
  )
  RETURNING * INTO v_row;

  RETURN jsonb_build_object(
    'id', v_row.id,
    'people_group_id', v_row.people_group_id,
    'name', v_row.name,
    'email', v_row.email,
    'role', v_row.role,
    'is_active', v_row.is_active,
    'created_at', v_row.created_at
  );
END;
$$;

ALTER FUNCTION "public"."create_pp_people_group_member"("p_tenant_id" bigint, "p_people_group_id" bigint, "p_name" "text", "p_email" "text", "p_role" "text") OWNER TO "postgres";