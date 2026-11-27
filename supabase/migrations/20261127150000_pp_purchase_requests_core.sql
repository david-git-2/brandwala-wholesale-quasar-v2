-- Proxy purchase: request + order line tables

CREATE TABLE IF NOT EXISTS "public"."pp_purchase_requests" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "people_group_id" bigint NOT NULL,
    "created_by_member_id" bigint NOT NULL,
    "status" "text" DEFAULT 'draft'::"text" NOT NULL,
    "request_number" "text",
    "bucket_description" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "deleted_at" timestamp with time zone,
    CONSTRAINT "pp_purchase_requests_status_check" CHECK (("status" = ANY (ARRAY['draft'::"text", 'post'::"text"]))),
    CONSTRAINT "pp_purchase_requests_request_number_not_blank" CHECK (("request_number" IS NULL OR "length"(TRIM(BOTH FROM "request_number")) > 0))
);

CREATE SEQUENCE IF NOT EXISTS "public"."pp_purchase_requests_id_seq"
    START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;

ALTER SEQUENCE "public"."pp_purchase_requests_id_seq" OWNER TO "postgres";
ALTER SEQUENCE "public"."pp_purchase_requests_id_seq" OWNED BY "public"."pp_purchase_requests"."id";
ALTER TABLE ONLY "public"."pp_purchase_requests" ALTER COLUMN "id" SET DEFAULT nextval('"public"."pp_purchase_requests_id_seq"'::regclass);

ALTER TABLE ONLY "public"."pp_purchase_requests"
    ADD CONSTRAINT "pp_purchase_requests_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."pp_purchase_requests"
    ADD CONSTRAINT "pp_purchase_requests_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."pp_purchase_requests"
    ADD CONSTRAINT "pp_purchase_requests_people_group_id_fkey" FOREIGN KEY ("people_group_id") REFERENCES "public"."pp_people_group"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."pp_purchase_requests"
    ADD CONSTRAINT "pp_purchase_requests_created_by_member_id_fkey" FOREIGN KEY ("created_by_member_id") REFERENCES "public"."pp_people_group_member"("id") ON DELETE RESTRICT;

CREATE INDEX IF NOT EXISTS "pp_purchase_requests_tenant_group_active_idx"
    ON "public"."pp_purchase_requests" ("tenant_id", "people_group_id", "created_at" DESC)
    WHERE ("deleted_at" IS NULL);

CREATE UNIQUE INDEX IF NOT EXISTS "pp_purchase_requests_tenant_number_active_uidx"
    ON "public"."pp_purchase_requests" ("tenant_id", "request_number")
    WHERE ("deleted_at" IS NULL AND "request_number" IS NOT NULL);

CREATE TABLE IF NOT EXISTS "public"."pp_order_lines" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "purchase_request_id" bigint NOT NULL,
    "url" "text" NOT NULL,
    "needed_qty" numeric NOT NULL,
    "description" "text",
    "status" "text" DEFAULT 'draft'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "deleted_at" timestamp with time zone,
    CONSTRAINT "pp_order_lines_url_not_blank" CHECK (("length"(TRIM(BOTH FROM "url")) > 0)),
    CONSTRAINT "pp_order_lines_needed_qty_positive" CHECK (("needed_qty" > (0)::numeric)),
    CONSTRAINT "pp_order_lines_status_check" CHECK (("status" = ANY (ARRAY['draft'::"text", 'pending_review'::"text"])))
);

CREATE SEQUENCE IF NOT EXISTS "public"."pp_order_lines_id_seq"
    START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;

ALTER SEQUENCE "public"."pp_order_lines_id_seq" OWNER TO "postgres";
ALTER SEQUENCE "public"."pp_order_lines_id_seq" OWNED BY "public"."pp_order_lines"."id";
ALTER TABLE ONLY "public"."pp_order_lines" ALTER COLUMN "id" SET DEFAULT nextval('"public"."pp_order_lines_id_seq"'::regclass);

ALTER TABLE ONLY "public"."pp_order_lines"
    ADD CONSTRAINT "pp_order_lines_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."pp_order_lines"
    ADD CONSTRAINT "pp_order_lines_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."pp_order_lines"
    ADD CONSTRAINT "pp_order_lines_purchase_request_id_fkey" FOREIGN KEY ("purchase_request_id") REFERENCES "public"."pp_purchase_requests"("id") ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS "pp_order_lines_request_active_idx"
    ON "public"."pp_order_lines" ("purchase_request_id", "created_at" ASC)
    WHERE ("deleted_at" IS NULL);

CREATE OR REPLACE TRIGGER "trg_pp_purchase_requests_updated_at"
    BEFORE UPDATE ON "public"."pp_purchase_requests"
    FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();

CREATE OR REPLACE TRIGGER "trg_pp_order_lines_updated_at"
    BEFORE UPDATE ON "public"."pp_order_lines"
    FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();

ALTER TABLE "public"."pp_purchase_requests" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."pp_order_lines" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "pp_purchase_requests_select" ON "public"."pp_purchase_requests"
    FOR SELECT TO "authenticated"
    USING ("public"."has_active_tenant_membership"("tenant_id"));

CREATE POLICY "pp_order_lines_select" ON "public"."pp_order_lines"
    FOR SELECT TO "authenticated"
    USING ("public"."has_active_tenant_membership"("tenant_id"));

GRANT ALL ON TABLE "public"."pp_purchase_requests" TO "anon", "authenticated", "service_role";
GRANT ALL ON TABLE "public"."pp_order_lines" TO "anon", "authenticated", "service_role";
GRANT ALL ON SEQUENCE "public"."pp_purchase_requests_id_seq" TO "anon", "authenticated", "service_role";
GRANT ALL ON SEQUENCE "public"."pp_order_lines_id_seq" TO "anon", "authenticated", "service_role";