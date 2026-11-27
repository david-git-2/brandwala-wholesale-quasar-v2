-- Proxy purchase: people groups

CREATE TABLE IF NOT EXISTS "public"."pp_people_group" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "name" "text" NOT NULL,
    "type" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "deleted_at" timestamp with time zone,
    CONSTRAINT "pp_people_group_name_not_blank" CHECK (("length"(TRIM(BOTH FROM "name")) > 0)),
    CONSTRAINT "pp_people_group_type_check" CHECK (("type" = ANY (ARRAY['customer'::"text", 'supplier'::"text"])))
);

ALTER TABLE "public"."pp_people_group" OWNER TO "postgres";

CREATE SEQUENCE IF NOT EXISTS "public"."pp_people_group_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE "public"."pp_people_group_id_seq" OWNER TO "postgres";
ALTER SEQUENCE "public"."pp_people_group_id_seq" OWNED BY "public"."pp_people_group"."id";
ALTER TABLE ONLY "public"."pp_people_group" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."pp_people_group_id_seq"'::"regclass");

ALTER TABLE ONLY "public"."pp_people_group"
    ADD CONSTRAINT "pp_people_group_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."pp_people_group"
    ADD CONSTRAINT "pp_people_group_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS "pp_people_group_tenant_type_active_idx" ON "public"."pp_people_group" USING "btree" ("tenant_id", "type") WHERE ("deleted_at" IS NULL);

CREATE TABLE IF NOT EXISTS "public"."pp_people_group_member" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "people_group_id" bigint NOT NULL,
    "name" "text" NOT NULL,
    "email" "text" NOT NULL,
    "role" "text" NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "deleted_at" timestamp with time zone,
    CONSTRAINT "pp_people_group_member_name_not_blank" CHECK (("length"(TRIM(BOTH FROM "name")) > 0)),
    CONSTRAINT "pp_people_group_member_email_not_blank" CHECK (("length"(TRIM(BOTH FROM "email")) > 0)),
    CONSTRAINT "pp_people_group_member_role_check" CHECK (("role" = ANY (ARRAY['admin'::"text", 'staff'::"text"])))
);

ALTER TABLE "public"."pp_people_group_member" OWNER TO "postgres";

CREATE SEQUENCE IF NOT EXISTS "public"."pp_people_group_member_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE "public"."pp_people_group_member_id_seq" OWNER TO "postgres";
ALTER SEQUENCE "public"."pp_people_group_member_id_seq" OWNED BY "public"."pp_people_group_member"."id";
ALTER TABLE ONLY "public"."pp_people_group_member" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."pp_people_group_member_id_seq"'::"regclass");

ALTER TABLE ONLY "public"."pp_people_group_member"
    ADD CONSTRAINT "pp_people_group_member_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."pp_people_group_member"
    ADD CONSTRAINT "pp_people_group_member_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."pp_people_group_member"
    ADD CONSTRAINT "pp_people_group_member_people_group_id_fkey" FOREIGN KEY ("people_group_id") REFERENCES "public"."pp_people_group"("id") ON DELETE CASCADE;

CREATE UNIQUE INDEX IF NOT EXISTS "pp_people_group_member_group_email_active_uidx"
    ON "public"."pp_people_group_member" ("people_group_id", "lower"(TRIM(BOTH FROM "email")))
    WHERE ("deleted_at" IS NULL);

CREATE INDEX IF NOT EXISTS "pp_people_group_member_group_active_idx"
    ON "public"."pp_people_group_member" ("people_group_id")
    WHERE ("deleted_at" IS NULL);

CREATE OR REPLACE TRIGGER "trg_pp_people_group_updated_at"
    BEFORE UPDATE ON "public"."pp_people_group"
    FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();

CREATE OR REPLACE TRIGGER "trg_pp_people_group_member_updated_at"
    BEFORE UPDATE ON "public"."pp_people_group_member"
    FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();