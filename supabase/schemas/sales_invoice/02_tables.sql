-- Extracted from supabase/schemas/public.sql (sales_invoice). Move-only.

CREATE TABLE IF NOT EXISTS "public"."billing_profiles" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "parent_tenant_id" bigint,
    "name" "text" NOT NULL,
    "email" "text",
    "customer_group_id" bigint,
    "phone" "text",
    "address" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "color" "text"
);

ALTER TABLE "public"."billing_profiles" OWNER TO "postgres";

CREATE SEQUENCE IF NOT EXISTS "public"."billing_profiles_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE "public"."billing_profiles_id_seq" OWNER TO "postgres";
ALTER SEQUENCE "public"."billing_profiles_id_seq" OWNED BY "public"."billing_profiles"."id";



CREATE TABLE IF NOT EXISTS "public"."recipient_profiles" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "parent_tenant_id" bigint,
    "name" "text" NOT NULL,
    "address" "text" NOT NULL,
    "phone" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "secondary_phone" "text",
    "district" "text",
    "thana" "text",
    "addresses" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL
);

ALTER TABLE "public"."recipient_profiles" OWNER TO "postgres";

CREATE SEQUENCE IF NOT EXISTS "public"."recipient_profiles_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE "public"."recipient_profiles_id_seq" OWNER TO "postgres";
ALTER SEQUENCE "public"."recipient_profiles_id_seq" OWNED BY "public"."recipient_profiles"."id";



CREATE TABLE IF NOT EXISTS "public"."invoice_brands" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "name" "text" NOT NULL,
    "address" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);

ALTER TABLE "public"."invoice_brands" OWNER TO "postgres";

CREATE SEQUENCE IF NOT EXISTS "public"."invoice_brands_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE "public"."invoice_brands_id_seq" OWNER TO "postgres";
ALTER SEQUENCE "public"."invoice_brands_id_seq" OWNED BY "public"."invoice_brands"."id";



CREATE TABLE IF NOT EXISTS "public"."sales_invoices" (
    "id" bigint NOT NULL,
    "parent_tenant_id" bigint NOT NULL,
    "invoice_no" "text" NOT NULL,
    "invoice_type" "public"."global_invoice_type" DEFAULT 'wholesale'::"public"."global_invoice_type" NOT NULL,
    "invoice_date" "date" DEFAULT CURRENT_DATE NOT NULL,
    "retail_billing_mode" "public"."retail_billing_mode",
    "invoice_status" "public"."global_invoice_status" DEFAULT 'draft'::"public"."global_invoice_status" NOT NULL,
    "fulfillment_status" "public"."global_fulfillment_status" DEFAULT 'pending'::"public"."global_fulfillment_status" NOT NULL,
    "billing_profile_id" bigint,
    "recipient_profile_id" bigint,
    "recipient_name" "text",
    "recipient_phone" "text",
    "recipient_address" "text",
    "collection_source" "public"."collection_source_type" NOT NULL,
    "due_date" "date",
    "payment_status" "text" DEFAULT 'due'::"text" NOT NULL,
    "total_amount" numeric(12,2) DEFAULT 0 NOT NULL,
    "due_amount" numeric(12,2) DEFAULT 0 NOT NULL,
    "paid_amount" numeric(12,2) DEFAULT 0 NOT NULL,
    "subtotal_amount" numeric(12,2) DEFAULT 0 NOT NULL,
    "discount_amount" numeric(12,2) DEFAULT 0 NOT NULL,
    "shipping_charge" numeric(12,2) DEFAULT 0 NOT NULL,
    "wrapping_charge" numeric(12,2) DEFAULT 0 NOT NULL,
    "print_charge" numeric(12,2) DEFAULT 0 NOT NULL,
    "note" "text",
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "settlement_discount_amount" numeric(12,2) DEFAULT 0 NOT NULL,
    "issued_by_tenant_id" bigint NOT NULL,
    CONSTRAINT "global_invoices_discount_amount_check" CHECK (("discount_amount" >= (0)::numeric)),
    CONSTRAINT "global_invoices_due_amount_check" CHECK (("due_amount" >= (0)::numeric)),
    CONSTRAINT "global_invoices_paid_amount_check" CHECK (("paid_amount" >= (0)::numeric)),
    CONSTRAINT "global_invoices_payment_status_check" CHECK (("payment_status" = ANY (ARRAY['due'::"text", 'partially_paid'::"text", 'paid'::"text"]))),
    CONSTRAINT "global_invoices_print_charge_check" CHECK (("print_charge" >= (0)::numeric)),
    CONSTRAINT "global_invoices_settlement_discount_amount_check" CHECK (("settlement_discount_amount" >= (0)::numeric)),
    CONSTRAINT "global_invoices_shipping_charge_check" CHECK (("shipping_charge" >= (0)::numeric)),
    CONSTRAINT "global_invoices_subtotal_amount_check" CHECK (("subtotal_amount" >= (0)::numeric)),
    CONSTRAINT "global_invoices_total_amount_check" CHECK (("total_amount" >= (0)::numeric)),
    CONSTRAINT "global_invoices_wrapping_charge_check" CHECK (("wrapping_charge" >= (0)::numeric))
);

ALTER TABLE "public"."sales_invoices" OWNER TO "postgres";
COMMENT ON TABLE "public"."sales_invoices" IS 'Sales invoices. parent_tenant_id = parent books/stock, issued_by_tenant_id = selling child.';

CREATE SEQUENCE IF NOT EXISTS "public"."global_invoices_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE "public"."global_invoices_id_seq" OWNER TO "postgres";
ALTER SEQUENCE "public"."global_invoices_id_seq" OWNED BY "public"."sales_invoices"."id";



CREATE TABLE IF NOT EXISTS "public"."sales_invoice_items" (
    "id" bigint NOT NULL,
    "parent_tenant_id" bigint NOT NULL,
    "invoice_id" bigint NOT NULL,
    "global_stock_id" bigint NOT NULL,
    "shipment_item_id" bigint,
    "product_id" bigint,
    "name_snapshot" "text" NOT NULL,
    "barcode_snapshot" "text",
    "product_code_snapshot" "text",
    "quantity" numeric(12,3) NOT NULL,
    "unit_cost_price" numeric(12,2) DEFAULT 0 NOT NULL,
    "sell_price_amount" numeric(12,2) DEFAULT 0 NOT NULL,
    "line_discount_amount" numeric(12,2) DEFAULT 0 NOT NULL,
    "line_total_amount" numeric(12,2) DEFAULT 0 NOT NULL,
    "return_quantity" numeric(12,3) DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "assigned_child_tenant_id" bigint,
    CONSTRAINT "global_invoice_items_line_discount_amount_check" CHECK (("line_discount_amount" >= (0)::numeric)),
    CONSTRAINT "global_invoice_items_line_total_amount_check" CHECK (("line_total_amount" >= (0)::numeric)),
    CONSTRAINT "global_invoice_items_quantity_check" CHECK (("quantity" > (0)::numeric)),
    CONSTRAINT "global_invoice_items_return_qty_check" CHECK (("return_quantity" <= "quantity")),
    CONSTRAINT "global_invoice_items_return_quantity_check" CHECK (("return_quantity" >= (0)::numeric)),
    CONSTRAINT "global_invoice_items_sell_price_amount_check" CHECK (("sell_price_amount" >= (0)::numeric)),
    CONSTRAINT "global_invoice_items_unit_cost_price_check" CHECK (("unit_cost_price" >= (0)::numeric))
);

ALTER TABLE "public"."sales_invoice_items" OWNER TO "postgres";

CREATE SEQUENCE IF NOT EXISTS "public"."global_invoice_items_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE "public"."global_invoice_items_id_seq" OWNER TO "postgres";
ALTER SEQUENCE "public"."global_invoice_items_id_seq" OWNED BY "public"."sales_invoice_items"."id";



CREATE TABLE IF NOT EXISTS "public"."sales_return_items" (
    "id" bigint NOT NULL,
    "parent_tenant_id" bigint NOT NULL,
    "invoice_id" bigint NOT NULL,
    "invoice_item_id" bigint NOT NULL,
    "global_stock_id" bigint NOT NULL,
    "quantity" numeric(12,3) NOT NULL,
    "return_charge_amount" numeric(12,2) DEFAULT 0 NOT NULL,
    "note" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "global_return_items_quantity_check" CHECK (("quantity" > (0)::numeric)),
    CONSTRAINT "global_return_items_return_charge_amount_check" CHECK (("return_charge_amount" >= (0)::numeric))
);

ALTER TABLE "public"."sales_return_items" OWNER TO "postgres";

CREATE SEQUENCE IF NOT EXISTS "public"."global_return_items_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE "public"."global_return_items_id_seq" OWNER TO "postgres";
ALTER SEQUENCE "public"."global_return_items_id_seq" OWNED BY "public"."sales_return_items"."id";



-- Compatibility Views

CREATE OR REPLACE VIEW "public"."global_invoices" WITH ("security_invoker"='false') AS
 SELECT "id",
    "parent_tenant_id" AS "tenant_id",
    "parent_tenant_id",
    "invoice_no",
    "invoice_type",
    "invoice_date",
    "retail_billing_mode",
    "invoice_status",
    "fulfillment_status",
    "billing_profile_id",
    "recipient_profile_id",
    "recipient_name",
    "recipient_phone",
    "recipient_address",
    "collection_source",
    "due_date",
    "payment_status",
    "total_amount",
    "due_amount",
    "paid_amount",
    "subtotal_amount",
    "discount_amount",
    "shipping_charge",
    "wrapping_charge",
    "print_charge",
    "note",
    "created_by",
    "created_at",
    "updated_at",
    "settlement_discount_amount",
    "issued_by_tenant_id"
   FROM "public"."sales_invoices";

ALTER VIEW "public"."global_invoices" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."global_invoice_items" WITH ("security_invoker"='false') AS
 SELECT "id",
    "parent_tenant_id" AS "tenant_id",
    "parent_tenant_id",
    "invoice_id",
    "global_stock_id",
    "shipment_item_id",
    "product_id",
    "name_snapshot",
    "barcode_snapshot",
    "product_code_snapshot",
    "quantity",
    "unit_cost_price",
    "sell_price_amount",
    "line_discount_amount",
    "line_total_amount",
    "return_quantity",
    "created_at",
    "updated_at",
    "assigned_child_tenant_id"
   FROM "public"."sales_invoice_items";

ALTER VIEW "public"."global_invoice_items" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."global_return_items" WITH ("security_invoker"='false') AS
 SELECT "id",
    "parent_tenant_id" AS "tenant_id",
    "parent_tenant_id",
    "invoice_id",
    "invoice_item_id",
    "global_stock_id",
    "quantity",
    "return_charge_amount",
    "note",
    "created_at",
    "updated_at"
   FROM "public"."sales_return_items";

ALTER VIEW "public"."global_return_items" OWNER TO "postgres";



-- Column Defaults

ALTER TABLE ONLY "public"."billing_profiles" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."billing_profiles_id_seq"'::"regclass");
ALTER TABLE ONLY "public"."invoice_brands" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."invoice_brands_id_seq"'::"regclass");
ALTER TABLE ONLY "public"."recipient_profiles" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."recipient_profiles_id_seq"'::"regclass");
ALTER TABLE ONLY "public"."sales_invoice_items" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."global_invoice_items_id_seq"'::"regclass");
ALTER TABLE ONLY "public"."sales_invoices" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."global_invoices_id_seq"'::"regclass");
ALTER TABLE ONLY "public"."sales_return_items" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."global_return_items_id_seq"'::"regclass");



-- Primary Keys & Unique Constraints

ALTER TABLE ONLY "public"."billing_profiles"
    ADD CONSTRAINT "billing_profiles_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."recipient_profiles"
    ADD CONSTRAINT "recipient_profiles_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."sales_invoice_items"
    ADD CONSTRAINT "global_invoice_items_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."sales_invoices"
    ADD CONSTRAINT "global_invoices_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."sales_invoices"
    ADD CONSTRAINT "sales_invoices_parent_tenant_id_invoice_no_key" UNIQUE ("parent_tenant_id", "invoice_no");

ALTER TABLE ONLY "public"."sales_return_items"
    ADD CONSTRAINT "global_return_items_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."invoice_brands"
    ADD CONSTRAINT "invoice_brands_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."invoice_brands"
    ADD CONSTRAINT "invoice_brands_tenant_id_name_key" UNIQUE ("tenant_id", "name");



-- Indexes

CREATE INDEX "billing_profiles_customer_group_id_idx" ON "public"."billing_profiles" USING "btree" ("customer_group_id");
CREATE INDEX "billing_profiles_name_idx" ON "public"."billing_profiles" USING "btree" ("name");
CREATE INDEX "billing_profiles_parent_tenant_id_idx" ON "public"."billing_profiles" USING "btree" ("parent_tenant_id");
CREATE INDEX "billing_profiles_tenant_id_idx" ON "public"."billing_profiles" USING "btree" ("tenant_id");
CREATE UNIQUE INDEX "billing_profiles_tenant_phone_uidx" ON "public"."billing_profiles" USING "btree" ("tenant_id", "phone") WHERE (("phone" IS NOT NULL) AND ("phone" <> ''::"text"));

CREATE INDEX "global_invoice_items_global_stock_id_idx" ON "public"."sales_invoice_items" USING "btree" ("global_stock_id");
CREATE INDEX "global_invoice_items_invoice_id_idx" ON "public"."sales_invoice_items" USING "btree" ("invoice_id");
CREATE INDEX "global_invoices_billing_profile_id_idx" ON "public"."sales_invoices" USING "btree" ("billing_profile_id");
CREATE INDEX "global_invoices_issued_by_tenant_id_idx" ON "public"."sales_invoices" USING "btree" ("issued_by_tenant_id");
CREATE INDEX "global_invoices_parent_tenant_id_idx" ON "public"."sales_invoices" USING "btree" ("parent_tenant_id");
CREATE INDEX "global_invoices_recipient_profile_id_idx" ON "public"."sales_invoices" USING "btree" ("recipient_profile_id");
CREATE INDEX "global_return_items_invoice_id_idx" ON "public"."sales_return_items" USING "btree" ("invoice_id");
CREATE INDEX "global_return_items_invoice_item_id_idx" ON "public"."sales_return_items" USING "btree" ("invoice_item_id");
CREATE INDEX "idx_global_invoice_items_shipment" ON "public"."sales_invoice_items" USING "btree" ("shipment_item_id");
CREATE INDEX "idx_global_invoices_billing_profile" ON "public"."sales_invoices" USING "btree" ("billing_profile_id");
CREATE INDEX "idx_sales_invoices_scoping" ON "public"."sales_invoices" USING "btree" ("parent_tenant_id", "issued_by_tenant_id", "invoice_status", "invoice_date");
CREATE INDEX "recipient_profiles_name_idx" ON "public"."recipient_profiles" USING "btree" ("name");
CREATE INDEX "recipient_profiles_parent_tenant_id_idx" ON "public"."recipient_profiles" USING "btree" ("parent_tenant_id");
CREATE INDEX "recipient_profiles_tenant_id_idx" ON "public"."recipient_profiles" USING "btree" ("tenant_id");
CREATE UNIQUE INDEX "recipient_profiles_tenant_phone_uidx" ON "public"."recipient_profiles" USING "btree" ("tenant_id", "phone");



-- Foreign Keys

ALTER TABLE ONLY "public"."billing_profiles"
    ADD CONSTRAINT "billing_profiles_customer_group_id_fkey" FOREIGN KEY ("customer_group_id") REFERENCES "public"."customer_groups"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."billing_profiles"
    ADD CONSTRAINT "billing_profiles_parent_tenant_id_fkey" FOREIGN KEY ("parent_tenant_id") REFERENCES "public"."tenants"("id") ON DELETE SET NULL;

ALTER TABLE ONLY "public"."billing_profiles"
    ADD CONSTRAINT "billing_profiles_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."sales_invoice_items"
    ADD CONSTRAINT "global_invoice_items_assigned_child_tenant_id_fkey" FOREIGN KEY ("assigned_child_tenant_id") REFERENCES "public"."tenants"("id");

ALTER TABLE ONLY "public"."sales_invoice_items"
    ADD CONSTRAINT "global_invoice_items_invoice_id_fkey" FOREIGN KEY ("invoice_id") REFERENCES "public"."sales_invoices"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."sales_invoice_items"
    ADD CONSTRAINT "global_invoice_items_parent_tenant_id_fkey" FOREIGN KEY ("parent_tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."sales_invoice_items"
    ADD CONSTRAINT "global_invoice_items_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE SET NULL;

ALTER TABLE ONLY "public"."sales_invoices"
    ADD CONSTRAINT "global_invoices_billing_profile_id_fkey" FOREIGN KEY ("billing_profile_id") REFERENCES "public"."billing_profiles"("id") ON DELETE RESTRICT;

ALTER TABLE ONLY "public"."sales_invoices"
    ADD CONSTRAINT "global_invoices_issued_by_tenant_id_fkey" FOREIGN KEY ("issued_by_tenant_id") REFERENCES "public"."tenants"("id");

ALTER TABLE ONLY "public"."sales_invoices"
    ADD CONSTRAINT "global_invoices_parent_tenant_id_fkey" FOREIGN KEY ("parent_tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."sales_invoices"
    ADD CONSTRAINT "global_invoices_recipient_profile_id_fkey" FOREIGN KEY ("recipient_profile_id") REFERENCES "public"."recipient_profiles"("id") ON DELETE RESTRICT;

ALTER TABLE ONLY "public"."sales_return_items"
    ADD CONSTRAINT "global_return_items_invoice_id_fkey" FOREIGN KEY ("invoice_id") REFERENCES "public"."sales_invoices"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."sales_return_items"
    ADD CONSTRAINT "global_return_items_invoice_item_id_fkey" FOREIGN KEY ("invoice_item_id") REFERENCES "public"."sales_invoice_items"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."sales_return_items"
    ADD CONSTRAINT "global_return_items_parent_tenant_id_fkey" FOREIGN KEY ("parent_tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."invoice_brands"
    ADD CONSTRAINT "invoice_brands_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."recipient_profiles"
    ADD CONSTRAINT "recipient_profiles_parent_tenant_id_fkey" FOREIGN KEY ("parent_tenant_id") REFERENCES "public"."tenants"("id") ON DELETE SET NULL;

ALTER TABLE ONLY "public"."recipient_profiles"
    ADD CONSTRAINT "recipient_profiles_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



CREATE TABLE IF NOT EXISTS "public"."sales_invoice_counters" (
    "tenant_id" bigint NOT NULL,
    "invoice_type" "public"."global_invoice_type" NOT NULL,
    "date_key" "text" NOT NULL,
    "last_value" bigint DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "sales_invoice_counters_pkey" PRIMARY KEY ("tenant_id", "invoice_type", "date_key"),
    CONSTRAINT "sales_invoice_counters_last_value_check" CHECK (("last_value" >= 0)),
    CONSTRAINT "sales_invoice_counters_date_key_check" CHECK (("date_key" ~ '^\d{8}$'::"text")),
    CONSTRAINT "sales_invoice_counters_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE
);

ALTER TABLE "public"."sales_invoice_counters" OWNER TO "postgres";

CREATE OR REPLACE TRIGGER "trg_sales_invoice_counters_set_updated_at"
BEFORE UPDATE ON "public"."sales_invoice_counters"
FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();
