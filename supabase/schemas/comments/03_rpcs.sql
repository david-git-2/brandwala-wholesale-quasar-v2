-- Comments kernel RPCs

CREATE OR REPLACE FUNCTION "public"."list_comments"(
    "p_tenant_id" bigint,
    "p_entity_type" "text",
    "p_entity_id" "text"
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

  RETURN (
    SELECT COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'id', "c"."id",
          'tenant_id', "c"."tenant_id",
          'entity_type', "c"."entity_type",
          'entity_id', "c"."entity_id",
          'body', "c"."body",
          'created_by', "c"."created_by",
          'created_at', "c"."created_at"
        )
        ORDER BY "c"."created_at" ASC
      ),
      '[]'::"jsonb"
    )
    FROM "public"."comments" "c"
    WHERE "c"."tenant_id" = "p_tenant_id"
      AND "c"."entity_type" = "p_entity_type"
      AND "c"."entity_id" = "p_entity_id"
      AND "c"."deleted_at" IS NULL
  );
END;
$$;

ALTER FUNCTION "public"."list_comments"("p_tenant_id" bigint, "p_entity_type" "text", "p_entity_id" "text") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."add_comment"(
    "p_tenant_id" bigint,
    "p_entity_type" "text",
    "p_entity_id" "text",
    "p_body" "text"
) RETURNS "jsonb"
    LANGUAGE "plpgsql"
    SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_body "text";
  v_row "public"."comments"%ROWTYPE;
BEGIN
  IF NOT "public"."has_active_tenant_membership"("p_tenant_id") THEN
    RAISE EXCEPTION 'Not allowed for tenant %', "p_tenant_id" USING ERRCODE = '42501';
  END IF;

  v_body := TRIM(BOTH FROM COALESCE("p_body", ''));
  IF "length"(v_body) = 0 THEN
    RAISE EXCEPTION 'Comment body is required' USING ERRCODE = '22023';
  END IF;

  INSERT INTO "public"."comments" (
    "tenant_id",
    "entity_type",
    "entity_id",
    "body",
    "created_by"
  )
  VALUES (
    "p_tenant_id",
    TRIM(BOTH FROM "p_entity_type"),
    TRIM(BOTH FROM "p_entity_id"),
    v_body,
    "public"."current_user_email"()
  )
  RETURNING * INTO v_row;

  RETURN jsonb_build_object(
    'id', v_row."id",
    'tenant_id', v_row."tenant_id",
    'entity_type', v_row."entity_type",
    'entity_id', v_row."entity_id",
    'body', v_row."body",
    'created_by', v_row."created_by",
    'created_at', v_row."created_at"
  );
END;
$$;

ALTER FUNCTION "public"."add_comment"("p_tenant_id" bigint, "p_entity_type" "text", "p_entity_id" "text", "p_body" "text") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."soft_delete_comment"(
    "p_tenant_id" bigint,
    "p_comment_id" bigint
) RETURNS "jsonb"
    LANGUAGE "plpgsql"
    SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_email "text";
  v_updated integer;
BEGIN
  IF NOT "public"."has_active_tenant_membership"("p_tenant_id") THEN
    RAISE EXCEPTION 'Not allowed for tenant %', "p_tenant_id" USING ERRCODE = '42501';
  END IF;

  v_email := "public"."current_user_email"();

  UPDATE "public"."comments"
  SET "deleted_at" = "now"()
  WHERE "id" = "p_comment_id"
    AND "tenant_id" = "p_tenant_id"
    AND "created_by" = v_email
    AND "deleted_at" IS NULL;

  GET DIAGNOSTICS v_updated = ROW_COUNT;

  IF v_updated = 0 THEN
    RAISE EXCEPTION 'Comment not found or not allowed to delete' USING ERRCODE = '42501';
  END IF;

  RETURN jsonb_build_object('ok', true, 'id', "p_comment_id");
END;
$$;

ALTER FUNCTION "public"."soft_delete_comment"("p_tenant_id" bigint, "p_comment_id" bigint) OWNER TO "postgres";