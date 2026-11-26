-- Comments kernel: polymorphic plain-text comments (replaces dropped tasks-module shape).

CREATE TABLE IF NOT EXISTS "public"."comments" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "entity_type" "text" NOT NULL,
    "entity_id" "text" NOT NULL,
    "body" "text" NOT NULL,
    "created_by" "text" DEFAULT "public"."current_user_email"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "deleted_at" timestamp with time zone,
    CONSTRAINT "comments_body_not_blank" CHECK (("length"(TRIM(BOTH FROM "body")) > 0)),
    CONSTRAINT "comments_entity_id_not_blank" CHECK (("length"(TRIM(BOTH FROM "entity_id")) > 0)),
    CONSTRAINT "comments_entity_type_not_blank" CHECK (("length"(TRIM(BOTH FROM "entity_type")) > 0))
);

ALTER TABLE "public"."comments" OWNER TO "postgres";

CREATE SEQUENCE IF NOT EXISTS "public"."comments_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE "public"."comments_id_seq" OWNER TO "postgres";
ALTER SEQUENCE "public"."comments_id_seq" OWNED BY "public"."comments"."id";
ALTER TABLE ONLY "public"."comments" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."comments_id_seq"'::"regclass");

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'comments_pkey' AND conrelid = 'public.comments'::regclass
  ) THEN
    ALTER TABLE ONLY "public"."comments" ADD CONSTRAINT "comments_pkey" PRIMARY KEY ("id");
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'comments_tenant_id_fkey' AND conrelid = 'public.comments'::regclass
  ) THEN
    ALTER TABLE ONLY "public"."comments"
      ADD CONSTRAINT "comments_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS "comments_entity_active_idx" ON "public"."comments" USING "btree" ("tenant_id", "entity_type", "entity_id") WHERE ("deleted_at" IS NULL);

DROP TRIGGER IF EXISTS "trg_comments_updated_at" ON "public"."comments";
CREATE TRIGGER "trg_comments_updated_at" BEFORE UPDATE ON "public"."comments" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();

DROP FUNCTION IF EXISTS "public"."get_item_details"(bigint);
DROP FUNCTION IF EXISTS "public"."global_search_tasks"(text);

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

ALTER TABLE "public"."comments" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "comments_select" ON "public"."comments";
CREATE POLICY "comments_select" ON "public"."comments" FOR SELECT TO "authenticated" USING ("public"."has_active_tenant_membership"("tenant_id"));

GRANT ALL ON TABLE "public"."comments" TO "anon";
GRANT ALL ON TABLE "public"."comments" TO "authenticated";
GRANT ALL ON TABLE "public"."comments" TO "service_role";

GRANT ALL ON SEQUENCE "public"."comments_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."comments_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."comments_id_seq" TO "service_role";

GRANT ALL ON FUNCTION "public"."list_comments"(bigint, text, text) TO "anon";
GRANT ALL ON FUNCTION "public"."list_comments"(bigint, text, text) TO "authenticated";
GRANT ALL ON FUNCTION "public"."list_comments"(bigint, text, text) TO "service_role";

GRANT ALL ON FUNCTION "public"."add_comment"(bigint, text, text, text) TO "anon";
GRANT ALL ON FUNCTION "public"."add_comment"(bigint, text, text, text) TO "authenticated";
GRANT ALL ON FUNCTION "public"."add_comment"(bigint, text, text, text) TO "service_role";

GRANT ALL ON FUNCTION "public"."soft_delete_comment"(bigint, bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."soft_delete_comment"(bigint, bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."soft_delete_comment"(bigint, bigint) TO "service_role";