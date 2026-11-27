-- Costing domain tables (extracted from public.sql)

CREATE TABLE IF NOT EXISTS "public"."costing_file_items" (
    "id" bigint NOT NULL,
    "costing_file_id" bigint NOT NULL,
    "name" "text",
    "image_url" "text",
    "website_url" "text" NOT NULL,
    "quantity" integer NOT NULL,
    "product_weight" integer,
    "package_weight" integer,
    "price_in_web_gbp" numeric(12,2),
    "delivery_price_gbp" numeric(12,2),
    "auxiliary_price_gbp" numeric(12,2),
    "item_price_gbp" numeric(12,2),
    "cargo_rate" numeric(12,2),
    "costing_price_gbp" numeric(12,2),
    "costing_price_bdt" integer,
    "offer_price_bdt" integer,
    "customer_profit_rate" numeric(12,2),
    "status" "public"."costing_file_item_status" DEFAULT 'pending'::"public"."costing_file_item_status" NOT NULL,
    "created_by_email" "text" DEFAULT "public"."current_user_email"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "offer_price_override_bdt" integer,
    "size" "text",
    "color" "text",
    "extra_information_1" "text",
    "extra_information_2" "text",
    "item_type" "text",
    "cargo_rate_is_manual" boolean DEFAULT false NOT NULL,
    "assigned_shipment_id" bigint,
    CONSTRAINT "costing_file_items_auxiliary_price_gbp_nonnegative" CHECK ((("auxiliary_price_gbp" IS NULL) OR ("auxiliary_price_gbp" >= (0)::numeric))),
    CONSTRAINT "costing_file_items_cargo_rate_nonnegative" CHECK ((("cargo_rate" IS NULL) OR ("cargo_rate" >= (0)::numeric))),
    CONSTRAINT "costing_file_items_costing_price_bdt_nonnegative" CHECK ((("costing_price_bdt" IS NULL) OR ("costing_price_bdt" >= 0))),
    CONSTRAINT "costing_file_items_costing_price_gbp_nonnegative" CHECK ((("costing_price_gbp" IS NULL) OR ("costing_price_gbp" >= (0)::numeric))),
    CONSTRAINT "costing_file_items_customer_profit_rate_nonnegative" CHECK ((("customer_profit_rate" IS NULL) OR ("customer_profit_rate" >= (0)::numeric))),
    CONSTRAINT "costing_file_items_delivery_price_gbp_nonnegative" CHECK ((("delivery_price_gbp" IS NULL) OR ("delivery_price_gbp" >= (0)::numeric))),
    CONSTRAINT "costing_file_items_item_price_gbp_nonnegative" CHECK ((("item_price_gbp" IS NULL) OR ("item_price_gbp" >= (0)::numeric))),
    CONSTRAINT "costing_file_items_item_type_not_blank" CHECK ((("item_type" IS NULL) OR ("length"(TRIM(BOTH FROM "item_type")) > 0))),
    CONSTRAINT "costing_file_items_offer_price_bdt_nonnegative" CHECK ((("offer_price_bdt" IS NULL) OR ("offer_price_bdt" >= 0))),
    CONSTRAINT "costing_file_items_offer_price_override_bdt_nonnegative" CHECK ((("offer_price_override_bdt" IS NULL) OR ("offer_price_override_bdt" >= 0))),
    CONSTRAINT "costing_file_items_package_weight_nonnegative" CHECK ((("package_weight" IS NULL) OR ("package_weight" >= 0))),
    CONSTRAINT "costing_file_items_price_in_web_gbp_nonnegative" CHECK ((("price_in_web_gbp" IS NULL) OR ("price_in_web_gbp" >= (0)::numeric))),
    CONSTRAINT "costing_file_items_product_weight_nonnegative" CHECK ((("product_weight" IS NULL) OR ("product_weight" >= 0))),
    CONSTRAINT "costing_file_items_quantity_positive" CHECK (("quantity" > 0)),
    CONSTRAINT "costing_file_items_website_url_not_blank" CHECK (("length"(TRIM(BOTH FROM "website_url")) > 0))
);

ALTER TABLE "public"."costing_file_items" OWNER TO "postgres";

CREATE SEQUENCE IF NOT EXISTS "public"."costing_file_items_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE "public"."costing_file_items_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."costing_file_items_id_seq" OWNED BY "public"."costing_file_items"."id";

CREATE TABLE IF NOT EXISTS "public"."costing_file_viewers" (
    "id" bigint NOT NULL,
    "costing_file_id" bigint NOT NULL,
    "membership_id" bigint NOT NULL,
    "created_by_email" "text" DEFAULT "public"."current_user_email"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);

ALTER TABLE "public"."costing_file_viewers" OWNER TO "postgres";

CREATE SEQUENCE IF NOT EXISTS "public"."costing_file_viewers_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE "public"."costing_file_viewers_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."costing_file_viewers_id_seq" OWNED BY "public"."costing_file_viewers"."id";

CREATE TABLE IF NOT EXISTS "public"."costing_files" (
    "id" bigint NOT NULL,
    "name" "text" NOT NULL,
    "cargo_rate_1kg" numeric(12,2),
    "cargo_rate_2kg" numeric(12,2),
    "conversion_rate" numeric(12,2),
    "admin_profit_rate" numeric(12,2),
    "status" "public"."costing_file_status" DEFAULT 'draft'::"public"."costing_file_status" NOT NULL,
    "market" "text",
    "customer_group_id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "created_by_email" "text" DEFAULT "public"."current_user_email"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "default_shipment_id" bigint,
    CONSTRAINT "costing_files_admin_profit_rate_nonnegative" CHECK ((("admin_profit_rate" IS NULL) OR ("admin_profit_rate" >= (0)::numeric))),
    CONSTRAINT "costing_files_cargo_rate_1kg_nonnegative" CHECK ((("cargo_rate_1kg" IS NULL) OR ("cargo_rate_1kg" >= (0)::numeric))),
    CONSTRAINT "costing_files_cargo_rate_2kg_nonnegative" CHECK ((("cargo_rate_2kg" IS NULL) OR ("cargo_rate_2kg" >= (0)::numeric))),
    CONSTRAINT "costing_files_conversion_rate_nonnegative" CHECK ((("conversion_rate" IS NULL) OR ("conversion_rate" >= (0)::numeric))),
    CONSTRAINT "costing_files_name_not_blank" CHECK (("length"(TRIM(BOTH FROM "name")) > 0))
);

ALTER TABLE "public"."costing_files" OWNER TO "postgres";

CREATE SEQUENCE IF NOT EXISTS "public"."costing_files_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE "public"."costing_files_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."costing_files_id_seq" OWNED BY "public"."costing_files"."id";

ALTER TABLE ONLY "public"."costing_file_items" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."costing_file_items_id_seq"'::"regclass");

ALTER TABLE ONLY "public"."costing_file_viewers" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."costing_file_viewers_id_seq"'::"regclass");

ALTER TABLE ONLY "public"."costing_files" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."costing_files_id_seq"'::"regclass");

ALTER TABLE ONLY "public"."costing_file_items"
    ADD CONSTRAINT "costing_file_items_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."costing_file_viewers"
    ADD CONSTRAINT "costing_file_viewers_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."costing_file_viewers"
    ADD CONSTRAINT "costing_file_viewers_unique" UNIQUE ("costing_file_id", "membership_id");

ALTER TABLE ONLY "public"."costing_files"
    ADD CONSTRAINT "costing_files_pkey" PRIMARY KEY ("id");

CREATE INDEX "costing_file_items_costing_file_id_idx" ON "public"."costing_file_items" USING "btree" ("costing_file_id");

CREATE INDEX "costing_file_items_status_idx" ON "public"."costing_file_items" USING "btree" ("status");

CREATE INDEX "costing_file_viewers_costing_file_id_idx" ON "public"."costing_file_viewers" USING "btree" ("costing_file_id");

CREATE INDEX "costing_file_viewers_membership_id_idx" ON "public"."costing_file_viewers" USING "btree" ("membership_id");

CREATE INDEX "costing_files_customer_group_id_idx" ON "public"."costing_files" USING "btree" ("customer_group_id");

CREATE INDEX "costing_files_status_idx" ON "public"."costing_files" USING "btree" ("status");

CREATE INDEX "costing_files_tenant_id_idx" ON "public"."costing_files" USING "btree" ("tenant_id");

ALTER TABLE ONLY "public"."costing_file_items"
    ADD CONSTRAINT "costing_file_items_assigned_shipment_id_fkey" FOREIGN KEY ("assigned_shipment_id") REFERENCES "public"."shipments"("id") ON DELETE SET NULL;

ALTER TABLE ONLY "public"."costing_file_items"
    ADD CONSTRAINT "costing_file_items_costing_file_id_fkey" FOREIGN KEY ("costing_file_id") REFERENCES "public"."costing_files"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."costing_file_viewers"
    ADD CONSTRAINT "costing_file_viewers_costing_file_id_fkey" FOREIGN KEY ("costing_file_id") REFERENCES "public"."costing_files"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."costing_file_viewers"
    ADD CONSTRAINT "costing_file_viewers_membership_id_fkey" FOREIGN KEY ("membership_id") REFERENCES "public"."memberships"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."costing_files"
    ADD CONSTRAINT "costing_files_customer_group_id_fkey" FOREIGN KEY ("customer_group_id") REFERENCES "public"."customer_groups"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."costing_files"
    ADD CONSTRAINT "costing_files_default_shipment_id_fkey" FOREIGN KEY ("default_shipment_id") REFERENCES "public"."shipments"("id") ON DELETE SET NULL;

ALTER TABLE ONLY "public"."costing_files"
    ADD CONSTRAINT "costing_files_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;
