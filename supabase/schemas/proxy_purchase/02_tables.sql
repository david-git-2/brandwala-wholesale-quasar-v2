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

-- Proxy purchase: shipments

CREATE TABLE IF NOT EXISTS "public"."pp_shipment" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "name" "text" NOT NULL,
    "shipment_code" "text" NOT NULL,
    "status" "text" DEFAULT 'draft'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "deleted_at" timestamp with time zone,
    CONSTRAINT "pp_shipment_name_not_blank" CHECK (("length"(TRIM(BOTH FROM "name")) > 0)),
    CONSTRAINT "pp_shipment_code_not_blank" CHECK (("length"(TRIM(BOTH FROM "shipment_code")) > 0)),
    CONSTRAINT "pp_shipment_status_check" CHECK (("status" = ANY (ARRAY['draft'::"text", 'in_transit'::"text", 'received'::"text", 'cancelled'::"text"])))
);

ALTER TABLE "public"."pp_shipment" OWNER TO "postgres";

CREATE SEQUENCE IF NOT EXISTS "public"."pp_shipment_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE "public"."pp_shipment_id_seq" OWNER TO "postgres";
ALTER SEQUENCE "public"."pp_shipment_id_seq" OWNED BY "public"."pp_shipment"."id";
ALTER TABLE ONLY "public"."pp_shipment" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."pp_shipment_id_seq"'::"regclass");

ALTER TABLE ONLY "public"."pp_shipment"
    ADD CONSTRAINT "pp_shipment_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."pp_shipment"
    ADD CONSTRAINT "pp_shipment_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

CREATE UNIQUE INDEX IF NOT EXISTS "pp_shipment_tenant_code_active_uidx"
    ON "public"."pp_shipment" ("tenant_id", "shipment_code")
    WHERE ("deleted_at" IS NULL);

CREATE INDEX IF NOT EXISTS "pp_shipment_tenant_active_idx"
    ON "public"."pp_shipment" ("tenant_id", "created_at" DESC)
    WHERE ("deleted_at" IS NULL);

CREATE OR REPLACE TRIGGER "trg_pp_shipment_updated_at"
    BEFORE UPDATE ON "public"."pp_shipment"
    FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();

-- Proxy purchase: purchase requests + order lines

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
    CONSTRAINT "pp_purchase_requests_status_check" CHECK (("status" = ANY (ARRAY['draft'::"text", 'requested'::"text"]))),
    CONSTRAINT "pp_purchase_requests_request_number_not_blank" CHECK (("request_number" IS NULL OR "length"(TRIM(BOTH FROM "request_number")) > 0))
);

ALTER TABLE "public"."pp_purchase_requests" OWNER TO "postgres";

CREATE SEQUENCE IF NOT EXISTS "public"."pp_purchase_requests_id_seq"
    START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;

ALTER SEQUENCE "public"."pp_purchase_requests_id_seq" OWNER TO "postgres";
ALTER SEQUENCE "public"."pp_purchase_requests_id_seq" OWNED BY "public"."pp_purchase_requests"."id";
ALTER TABLE ONLY "public"."pp_purchase_requests" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."pp_purchase_requests_id_seq"'::"regclass");

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
    "pp_customer_group_id" bigint NOT NULL,
    "url" "text" NOT NULL,
    "needed_qty" numeric NOT NULL,
    "description" "text",
    "product_name" "text",
    "image_url" "text",
    "unit_price" numeric,
    "pp_supplier_group_id" bigint,
    "shipment_id" bigint,
    "is_added_to_cart" boolean DEFAULT false NOT NULL,
    "added_to_cart_at" timestamp with time zone,
    "placement_status" "text" DEFAULT 'none'::"text" NOT NULL,
    "placed_qty" numeric,
    "status" "text" DEFAULT 'draft'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "deleted_at" timestamp with time zone,
    CONSTRAINT "pp_order_lines_url_not_blank" CHECK (("length"(TRIM(BOTH FROM "url")) > 0)),
    CONSTRAINT "pp_order_lines_needed_qty_positive" CHECK (("needed_qty" > (0)::numeric)),
    CONSTRAINT "pp_order_lines_status_check" CHECK (("status" = ANY (ARRAY['draft'::"text", 'requested'::"text", 'processing'::"text", 'done'::"text", 'cancelled'::"text"]))),
    CONSTRAINT "pp_order_lines_placement_status_check" CHECK (("placement_status" = ANY (ARRAY['none'::"text", 'added_to_cart'::"text", 'order_placed'::"text", 'cargo_warehouse'::"text", 'in_flight'::"text", 'local_warehouse'::"text", 'delivered'::"text", 'lost'::"text"])))
);

ALTER TABLE "public"."pp_order_lines" OWNER TO "postgres";

CREATE SEQUENCE IF NOT EXISTS "public"."pp_order_lines_id_seq"
    START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;

ALTER SEQUENCE "public"."pp_order_lines_id_seq" OWNER TO "postgres";
ALTER SEQUENCE "public"."pp_order_lines_id_seq" OWNED BY "public"."pp_order_lines"."id";
ALTER TABLE ONLY "public"."pp_order_lines" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."pp_order_lines_id_seq"'::"regclass");

ALTER TABLE ONLY "public"."pp_order_lines"
    ADD CONSTRAINT "pp_order_lines_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."pp_order_lines"
    ADD CONSTRAINT "pp_order_lines_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."pp_order_lines"
    ADD CONSTRAINT "pp_order_lines_purchase_request_id_fkey" FOREIGN KEY ("purchase_request_id") REFERENCES "public"."pp_purchase_requests"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."pp_order_lines"
    ADD CONSTRAINT "pp_order_lines_pp_customer_group_id_fkey" FOREIGN KEY ("pp_customer_group_id") REFERENCES "public"."pp_people_group"("id") ON DELETE RESTRICT;

ALTER TABLE ONLY "public"."pp_order_lines"
    ADD CONSTRAINT "pp_order_lines_pp_supplier_group_id_fkey" FOREIGN KEY ("pp_supplier_group_id") REFERENCES "public"."pp_people_group"("id") ON DELETE SET NULL;

ALTER TABLE ONLY "public"."pp_order_lines"
    ADD CONSTRAINT "pp_order_lines_shipment_id_fkey" FOREIGN KEY ("shipment_id") REFERENCES "public"."pp_shipment"("id") ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS "pp_order_lines_request_active_idx"
    ON "public"."pp_order_lines" ("purchase_request_id", "created_at" ASC)
    WHERE ("deleted_at" IS NULL);

CREATE INDEX IF NOT EXISTS "pp_order_lines_customer_group_active_idx"
    ON "public"."pp_order_lines" ("pp_customer_group_id", "created_at" DESC)
    WHERE ("deleted_at" IS NULL);

CREATE OR REPLACE TRIGGER "trg_pp_purchase_requests_updated_at"
    BEFORE UPDATE ON "public"."pp_purchase_requests"
    FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();

CREATE OR REPLACE TRIGGER "trg_pp_order_lines_updated_at"
    BEFORE UPDATE ON "public"."pp_order_lines"
    FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();