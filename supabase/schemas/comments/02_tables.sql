-- Comments kernel tables

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

ALTER TABLE ONLY "public"."comments"
    ADD CONSTRAINT "comments_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."comments"
    ADD CONSTRAINT "comments_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS "comments_entity_active_idx" ON "public"."comments" USING "btree" ("tenant_id", "entity_type", "entity_id") WHERE ("deleted_at" IS NULL);

CREATE OR REPLACE TRIGGER "trg_comments_updated_at" BEFORE UPDATE ON "public"."comments" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();