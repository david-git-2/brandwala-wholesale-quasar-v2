-- bills_pays: profiles, bills, bill lines/charges, pays, allocations, cashbook tables + views.

CREATE TABLE IF NOT EXISTS "public"."cashbook_entries" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tenant_id" bigint NOT NULL,
    "entity_type" "text" NOT NULL,
    "entity_id" bigint NOT NULL,
    "type" "text" NOT NULL,
    "amount" numeric(15,4) NOT NULL,
    "currency_code" "text" DEFAULT 'BDT'::"text" NOT NULL,
    "exchange_rate" numeric(15,6) DEFAULT 1.000000 NOT NULL,
    "base_amount" numeric(15,4) NOT NULL,
    "balance_after" numeric(15,4) NOT NULL,
    "source_type" "text" NOT NULL,
    "source_id" "text",
    "metadata" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "parent_tenant_id" bigint NOT NULL,
    "operating_tenant_id" bigint NOT NULL,
    CONSTRAINT "universal_wallet_ledger_amount_check" CHECK (("amount" >= (0)::numeric)),
    CONSTRAINT "universal_wallet_ledger_base_amount_check" CHECK (("base_amount" >= (0)::numeric)),
    CONSTRAINT "universal_wallet_ledger_exchange_rate_check" CHECK (("exchange_rate" > (0)::numeric)),
    CONSTRAINT "universal_wallet_ledger_type_check" CHECK (("type" = ANY (ARRAY['credit'::"text", 'debit'::"text"])))
);

ALTER TABLE "public"."cashbook_entries" OWNER TO "postgres";

CREATE TABLE IF NOT EXISTS "public"."bill_lines" (
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
    "sell_price_amount" numeric(12,2) DEFAULT 0 NOT NULL,
    "line_discount_amount" numeric(12,2) DEFAULT 0 NOT NULL,
    "line_total_amount" numeric(12,2) DEFAULT 0 NOT NULL,
    "return_quantity" numeric(12,3) DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "assigned_child_tenant_id" bigint,
    "line_meta" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    CONSTRAINT "global_invoice_items_line_discount_amount_check" CHECK (("line_discount_amount" >= (0)::numeric)),
    CONSTRAINT "global_invoice_items_line_total_amount_check" CHECK (("line_total_amount" >= (0)::numeric)),
    CONSTRAINT "global_invoice_items_quantity_check" CHECK (("quantity" > (0)::numeric)),
    CONSTRAINT "global_invoice_items_return_qty_check" CHECK (("return_quantity" <= "quantity")),
    CONSTRAINT "global_invoice_items_return_quantity_check" CHECK (("return_quantity" >= (0)::numeric)),
    CONSTRAINT "global_invoice_items_sell_price_amount_check" CHECK (("sell_price_amount" >= (0)::numeric))
);

ALTER TABLE "public"."bill_lines" OWNER TO "postgres";

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

CREATE TABLE IF NOT EXISTS "public"."pay_allocations" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "payment_id" bigint NOT NULL,
    "invoice_id" bigint,
    "amount" numeric(12,2) NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "global_invoice_id" bigint,
    "commerce_invoice_id" bigint,
    CONSTRAINT "payment_allocations_amount_check" CHECK (("amount" > (0)::numeric))
);

ALTER TABLE "public"."pay_allocations" OWNER TO "postgres";

CREATE TABLE IF NOT EXISTS "public"."bills" (
    "id" bigint NOT NULL,
    "parent_tenant_id" bigint NOT NULL,
    "invoice_no" "text" NOT NULL,
    "invoice_type" "public"."global_invoice_type" DEFAULT 'wholesale'::"public"."global_invoice_type" NOT NULL,
    "invoice_date" "date" DEFAULT CURRENT_DATE NOT NULL,
    "retail_billing_mode" "public"."retail_billing_mode",
    "invoice_status" "public"."global_invoice_status" DEFAULT 'draft'::"public"."global_invoice_status" NOT NULL,
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
    "issued_by_tenant_id" bigint NOT NULL,
    "written_off_amount" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "shop_order_id" bigint,
    "charges_amount" numeric(12,2) DEFAULT 0 NOT NULL,
    "channel_meta" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "profile_id" bigint,
    CONSTRAINT "global_invoices_charges_amount_check" CHECK (("charges_amount" >= (0)::numeric)),
    CONSTRAINT "global_invoices_discount_amount_check" CHECK (("discount_amount" >= (0)::numeric)),
    CONSTRAINT "global_invoices_due_amount_check" CHECK (("due_amount" >= (0)::numeric)),
    CONSTRAINT "global_invoices_paid_amount_check" CHECK (("paid_amount" >= (0)::numeric)),
    CONSTRAINT "global_invoices_payment_status_check" CHECK (("payment_status" = ANY (ARRAY['due'::"text", 'partially_paid'::"text", 'paid'::"text", 'settled_with_write_off'::"text"]))),
    CONSTRAINT "global_invoices_print_charge_check" CHECK (("print_charge" >= (0)::numeric)),
    CONSTRAINT "global_invoices_shipping_charge_check" CHECK (("shipping_charge" >= (0)::numeric)),
    CONSTRAINT "global_invoices_subtotal_amount_check" CHECK (("subtotal_amount" >= (0)::numeric)),
    CONSTRAINT "global_invoices_total_amount_check" CHECK (("total_amount" >= (0)::numeric)),
    CONSTRAINT "global_invoices_wrapping_charge_check" CHECK (("wrapping_charge" >= (0)::numeric)),
    CONSTRAINT "sales_invoices_written_off_amount_check" CHECK (("written_off_amount" >= (0)::numeric))
);

ALTER TABLE "public"."bills" OWNER TO "postgres";

COMMENT ON TABLE "public"."bills" IS 'Bills (spec). parent_tenant_id = parent books/stock, issued_by_tenant_id = selling child. Channel extras (COD, fulfillment) live in channel_meta.';

CREATE TABLE IF NOT EXISTS "public"."pays" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "amount" numeric(12,2) NOT NULL,
    "payment_date" "date" DEFAULT CURRENT_DATE NOT NULL,
    "method" "text",
    "reference" "text",
    "note" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "unallocated_amount" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "collection_source" "public"."collection_source_type" DEFAULT 'billing_profile'::"public"."collection_source_type" NOT NULL,
    "customer_group_id" bigint,
    "voided_at" timestamp with time zone,
    "shop_order_id" bigint,
    "profile_id" bigint,
    "source" "text" DEFAULT 'customer_cash'::"text" NOT NULL,
    CONSTRAINT "payments_amount_check" CHECK (("amount" >= (0)::numeric)),
    CONSTRAINT "payments_method_check" CHECK ((("method" IS NULL) OR ("method" = ANY (ARRAY['cash'::"text", 'bank'::"text", 'bank_transfer'::"text", 'mobile_banking'::"text", 'bkash'::"text", 'nagad'::"text", 'other'::"text", 'cheque'::"text", 'rocket'::"text", 'upay'::"text", 'tap'::"text", 'card_pos'::"text", 'wire_transfer'::"text", 'paypal'::"text", 'stripe'::"text", 'letter_of_credit'::"text", 'cod'::"text", 'split'::"text", 'store_credit'::"text"])))),
    CONSTRAINT "pays_source_check" CHECK (("source" = ANY (ARRAY['customer_cash'::"text", 'bank'::"text", 'store_credit'::"text", 'courier_remittance'::"text"])))
);

ALTER TABLE "public"."pays" OWNER TO "postgres";

CREATE TABLE IF NOT EXISTS "public"."bill_charges" (
    "id" bigint NOT NULL,
    "invoice_id" bigint NOT NULL,
    "parent_tenant_id" bigint NOT NULL,
    "charge_type" "public"."invoice_charge_type" NOT NULL,
    "amount" numeric(12,2) DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "sales_invoice_charges_amount_check" CHECK (("amount" >= (0)::numeric))
);

ALTER TABLE "public"."bill_charges" OWNER TO "postgres";

CREATE TABLE IF NOT EXISTS "public"."billing_profiles" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "name" "text" NOT NULL,
    "email" "text",
    "customer_group_id" bigint,
    "phone" "text",
    "address" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "color" "text",
    "parent_tenant_id" bigint NOT NULL,
    "phone_country_code" "text" DEFAULT '+880'::"text" NOT NULL,
    "is_phone_unique" boolean DEFAULT true NOT NULL
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

CREATE TABLE IF NOT EXISTS "public"."cashbook_accounts" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "entity_type" "text" NOT NULL,
    "entity_id" bigint NOT NULL,
    "currency_code" "text" DEFAULT 'BDT'::"text" NOT NULL,
    "available_balance" numeric(18,4) DEFAULT 0.0000 NOT NULL,
    "pending_balance" numeric(18,4) DEFAULT 0.0000 NOT NULL,
    "locked_balance" numeric(18,4) DEFAULT 0.0000 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "parent_tenant_id" bigint NOT NULL,
    CONSTRAINT "wallet_accounts_available_non_negative" CHECK ((("available_balance" >= (0)::numeric) OR ("entity_type" = 'tenant'::"text")))
);

ALTER TABLE "public"."cashbook_accounts" OWNER TO "postgres";

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
    "sell_price_amount",
    "line_discount_amount",
    "line_total_amount",
    "return_quantity",
    "created_at",
    "updated_at",
    "assigned_child_tenant_id",
    "line_meta"
   FROM "public"."bill_lines";

ALTER VIEW "public"."global_invoice_items" OWNER TO "postgres";

CREATE SEQUENCE IF NOT EXISTS "public"."global_invoice_items_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE "public"."global_invoice_items_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."global_invoice_items_id_seq" OWNED BY "public"."bill_lines"."id";

CREATE SEQUENCE IF NOT EXISTS "public"."global_invoices_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE "public"."global_invoices_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."global_invoices_id_seq" OWNED BY "public"."bills"."id";

CREATE TABLE IF NOT EXISTS "public"."pay_instruments" (
    "id" bigint NOT NULL,
    "payment_id" bigint NOT NULL,
    "payment_method_code" "text" NOT NULL,
    "amount" numeric(12,2) NOT NULL,
    "reference" "text",
    "bd_bank_id" bigint,
    "cheque_number" "text",
    "cheque_date" "date",
    "sort_order" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "global_payment_instruments_amount_positive" CHECK (("amount" > (0)::numeric)),
    CONSTRAINT "global_payment_instruments_cheque_fields" CHECK ((("payment_method_code" <> 'CHEQUE'::"text") OR (("bd_bank_id" IS NOT NULL) AND (NULLIF(TRIM(BOTH FROM "cheque_number"), ''::"text") IS NOT NULL) AND ("cheque_date" IS NOT NULL))))
);

ALTER TABLE "public"."pay_instruments" OWNER TO "postgres";

CREATE SEQUENCE IF NOT EXISTS "public"."global_payment_instruments_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE "public"."global_payment_instruments_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."global_payment_instruments_id_seq" OWNED BY "public"."pay_instruments"."id";

CREATE OR REPLACE VIEW "public"."global_return_items" WITH ("security_invoker"='false') AS
 SELECT "id",
    "parent_tenant_id",
    "parent_tenant_id" AS "tenant_id",
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

CREATE SEQUENCE IF NOT EXISTS "public"."global_return_items_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE "public"."global_return_items_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."global_return_items_id_seq" OWNED BY "public"."sales_return_items"."id";

CREATE TABLE IF NOT EXISTS "public"."invoice_brands" (
    "id" bigint NOT NULL,
    "parent_tenant_id" bigint NOT NULL,
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

CREATE TABLE IF NOT EXISTS "public"."invoice_write_offs" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "parent_tenant_id" bigint NOT NULL,
    "invoice_id" bigint NOT NULL,
    "payment_id" bigint,
    "amount" numeric(12,2) NOT NULL,
    "reason" "text" NOT NULL,
    "note" "text",
    "approved_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "invoice_write_offs_amount_check" CHECK (("amount" > (0)::numeric)),
    CONSTRAINT "invoice_write_offs_reason_check" CHECK (("reason" = ANY (ARRAY['dispute_settlement'::"text", 'bad_debt'::"text", 'currency_rounding'::"text", 'management_concession'::"text"])))
);

ALTER TABLE "public"."invoice_write_offs" OWNER TO "postgres";

ALTER TABLE "public"."invoice_write_offs" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."invoice_write_offs_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

CREATE SEQUENCE IF NOT EXISTS "public"."payment_allocations_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE "public"."payment_allocations_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."payment_allocations_id_seq" OWNED BY "public"."pay_allocations"."id";

CREATE SEQUENCE IF NOT EXISTS "public"."payments_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE "public"."payments_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."payments_id_seq" OWNED BY "public"."pays"."id";

CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" bigint NOT NULL,
    "parent_tenant_id" bigint NOT NULL,
    "profile_type" "public"."profile_party_type" DEFAULT 'customer'::"public"."profile_party_type" NOT NULL,
    "subject_id" bigint NOT NULL,
    "name" "text" NOT NULL,
    "email" "text",
    "phone" "text",
    "phone_country_code" "text" DEFAULT '+880'::"text" NOT NULL,
    "address" "text",
    "is_phone_unique" boolean DEFAULT true NOT NULL,
    "accent_color" "text",
    "is_active" boolean DEFAULT true NOT NULL,
    "deleted_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);

ALTER TABLE "public"."profiles" OWNER TO "postgres";

ALTER TABLE "public"."profiles" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."profiles_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

CREATE TABLE IF NOT EXISTS "public"."recipient_profiles" (
    "id" bigint NOT NULL,
    "tenant_id" bigint,
    "name" "text" NOT NULL,
    "address" "text" NOT NULL,
    "phone" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "secondary_phone" "text",
    "district" "text",
    "thana" "text",
    "addresses" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    "parent_tenant_id" bigint
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

CREATE SEQUENCE IF NOT EXISTS "public"."sales_invoice_charges_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE "public"."sales_invoice_charges_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."sales_invoice_charges_id_seq" OWNED BY "public"."bill_charges"."id";

CREATE TABLE IF NOT EXISTS "public"."sales_invoice_counters" (
    "tenant_id" bigint NOT NULL,
    "invoice_type" "public"."global_invoice_type" NOT NULL,
    "date_key" "text" NOT NULL,
    "last_value" bigint DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "sales_invoice_counters_date_key_check" CHECK (("date_key" ~ '^\d{8}$'::"text")),
    CONSTRAINT "sales_invoice_counters_last_value_check" CHECK (("last_value" >= 0))
);

ALTER TABLE "public"."sales_invoice_counters" OWNER TO "postgres";

ALTER TABLE "public"."cashbook_accounts" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."wallet_accounts_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

ALTER TABLE ONLY "public"."bill_charges" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."sales_invoice_charges_id_seq"'::"regclass");

ALTER TABLE ONLY "public"."bill_lines" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."global_invoice_items_id_seq"'::"regclass");

ALTER TABLE ONLY "public"."billing_profiles" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."billing_profiles_id_seq"'::"regclass");

ALTER TABLE ONLY "public"."bills" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."global_invoices_id_seq"'::"regclass");

ALTER TABLE ONLY "public"."invoice_brands" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."invoice_brands_id_seq"'::"regclass");

ALTER TABLE ONLY "public"."pay_allocations" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."payment_allocations_id_seq"'::"regclass");

ALTER TABLE ONLY "public"."pay_instruments" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."global_payment_instruments_id_seq"'::"regclass");

ALTER TABLE ONLY "public"."pays" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."payments_id_seq"'::"regclass");

ALTER TABLE ONLY "public"."recipient_profiles" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."recipient_profiles_id_seq"'::"regclass");

ALTER TABLE ONLY "public"."sales_return_items" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."global_return_items_id_seq"'::"regclass");

ALTER TABLE ONLY "public"."billing_profiles"
    ADD CONSTRAINT "billing_profiles_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."bill_lines"
    ADD CONSTRAINT "global_invoice_items_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."bills"
    ADD CONSTRAINT "global_invoices_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."pay_instruments"
    ADD CONSTRAINT "global_payment_instruments_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."sales_return_items"
    ADD CONSTRAINT "global_return_items_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."invoice_brands"
    ADD CONSTRAINT "invoice_brands_parent_tenant_id_name_key" UNIQUE ("parent_tenant_id", "name");

ALTER TABLE ONLY "public"."invoice_brands"
    ADD CONSTRAINT "invoice_brands_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."invoice_write_offs"
    ADD CONSTRAINT "invoice_write_offs_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."pay_allocations"
    ADD CONSTRAINT "payment_allocations_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."pays"
    ADD CONSTRAINT "payments_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_party_unique" UNIQUE ("parent_tenant_id", "profile_type", "subject_id");

ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."recipient_profiles"
    ADD CONSTRAINT "recipient_profiles_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."bill_charges"
    ADD CONSTRAINT "sales_invoice_charges_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."sales_invoice_counters"
    ADD CONSTRAINT "sales_invoice_counters_pkey" PRIMARY KEY ("tenant_id", "invoice_type", "date_key");

ALTER TABLE ONLY "public"."bills"
    ADD CONSTRAINT "sales_invoices_parent_tenant_id_invoice_no_key" UNIQUE ("parent_tenant_id", "invoice_no");

ALTER TABLE ONLY "public"."cashbook_entries"
    ADD CONSTRAINT "universal_wallet_ledger_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."cashbook_accounts"
    ADD CONSTRAINT "wallet_accounts_entity_currency_key" UNIQUE ("tenant_id", "entity_type", "entity_id", "currency_code");

ALTER TABLE ONLY "public"."cashbook_accounts"
    ADD CONSTRAINT "wallet_accounts_pkey" PRIMARY KEY ("id");

CREATE INDEX "billing_profiles_customer_group_id_idx" ON "public"."billing_profiles" USING "btree" ("customer_group_id");

CREATE INDEX "billing_profiles_name_idx" ON "public"."billing_profiles" USING "btree" ("name");

CREATE UNIQUE INDEX "billing_profiles_parent_phone_uidx" ON "public"."billing_profiles" USING "btree" ("parent_tenant_id", "phone_country_code", "phone") WHERE (("phone" IS NOT NULL) AND ("btrim"("phone") <> ''::"text") AND "is_phone_unique");

CREATE INDEX "billing_profiles_parent_tenant_id_idx" ON "public"."billing_profiles" USING "btree" ("parent_tenant_id");

CREATE INDEX "billing_profiles_tenant_id_idx" ON "public"."billing_profiles" USING "btree" ("tenant_id");

CREATE INDEX "bills_profile_id_idx" ON "public"."bills" USING "btree" ("profile_id");

CREATE INDEX "global_invoice_items_global_stock_id_idx" ON "public"."bill_lines" USING "btree" ("global_stock_id");

CREATE INDEX "global_invoice_items_invoice_id_idx" ON "public"."bill_lines" USING "btree" ("invoice_id");

CREATE INDEX "global_invoices_issued_by_tenant_id_idx" ON "public"."bills" USING "btree" ("issued_by_tenant_id");

CREATE INDEX "global_invoices_parent_tenant_id_idx" ON "public"."bills" USING "btree" ("parent_tenant_id");

CREATE INDEX "global_invoices_recipient_profile_id_idx" ON "public"."bills" USING "btree" ("recipient_profile_id");

CREATE INDEX "global_payment_instruments_method_code_idx" ON "public"."pay_instruments" USING "btree" ("payment_method_code");

CREATE INDEX "global_payment_instruments_payment_id_idx" ON "public"."pay_instruments" USING "btree" ("payment_id");

CREATE INDEX "global_payments_voided_at_idx" ON "public"."pays" USING "btree" ("voided_at") WHERE ("voided_at" IS NOT NULL);

CREATE INDEX "global_return_items_invoice_id_idx" ON "public"."sales_return_items" USING "btree" ("invoice_id");

CREATE INDEX "global_return_items_invoice_item_id_idx" ON "public"."sales_return_items" USING "btree" ("invoice_item_id");

CREATE INDEX "idx_global_invoice_items_shipment" ON "public"."bill_lines" USING "btree" ("shipment_item_id");

CREATE INDEX "idx_global_payments_customer_group_id" ON "public"."pays" USING "btree" ("customer_group_id");

CREATE INDEX "idx_global_payments_shop_order_id" ON "public"."pays" USING "btree" ("shop_order_id") WHERE ("shop_order_id" IS NOT NULL);

CREATE INDEX "idx_invoice_write_offs_invoice_id" ON "public"."invoice_write_offs" USING "btree" ("invoice_id");

CREATE INDEX "idx_invoice_write_offs_parent_tenant_id" ON "public"."invoice_write_offs" USING "btree" ("parent_tenant_id");

CREATE INDEX "idx_invoice_write_offs_payment_id" ON "public"."invoice_write_offs" USING "btree" ("payment_id");

CREATE INDEX "idx_invoice_write_offs_tenant_id" ON "public"."invoice_write_offs" USING "btree" ("tenant_id");

CREATE INDEX "idx_sales_invoice_charges_invoice_id" ON "public"."bill_charges" USING "btree" ("invoice_id");

CREATE INDEX "idx_sales_invoices_scoping" ON "public"."bills" USING "btree" ("parent_tenant_id", "issued_by_tenant_id", "invoice_status", "invoice_date");

CREATE INDEX "idx_sales_invoices_shop_order_id" ON "public"."bills" USING "btree" ("shop_order_id");

CREATE INDEX "idx_universal_wallet_ledger_lookup" ON "public"."cashbook_entries" USING "btree" ("tenant_id", "entity_type", "entity_id", "created_at" DESC, "id" DESC);

CREATE INDEX "idx_universal_wallet_ledger_source" ON "public"."cashbook_entries" USING "btree" ("source_type", "source_id");

CREATE INDEX "idx_uwl_operating_source" ON "public"."cashbook_entries" USING "btree" ("operating_tenant_id", "source_type", "source_id");

CREATE INDEX "idx_uwl_parent_book_lookup" ON "public"."cashbook_entries" USING "btree" ("parent_tenant_id", "entity_type", "entity_id", "created_at" DESC, "id" DESC);

CREATE INDEX "idx_uwl_parent_operating_created" ON "public"."cashbook_entries" USING "btree" ("parent_tenant_id", "operating_tenant_id", "created_at" DESC);

CREATE INDEX "idx_wallet_accounts_tenant_entity" ON "public"."cashbook_accounts" USING "btree" ("tenant_id", "entity_type", "entity_id");

CREATE INDEX "invoice_brands_parent_tenant_id_idx" ON "public"."invoice_brands" USING "btree" ("parent_tenant_id");

CREATE INDEX "payment_allocations_commerce_invoice_id_idx" ON "public"."pay_allocations" USING "btree" ("commerce_invoice_id");

CREATE INDEX "payment_allocations_global_invoice_id_idx" ON "public"."pay_allocations" USING "btree" ("global_invoice_id");

CREATE INDEX "payment_allocations_invoice_id_idx" ON "public"."pay_allocations" USING "btree" ("invoice_id");

CREATE INDEX "payment_allocations_payment_id_idx" ON "public"."pay_allocations" USING "btree" ("payment_id");

CREATE INDEX "payment_allocations_tenant_id_idx" ON "public"."pay_allocations" USING "btree" ("tenant_id");

CREATE INDEX "payments_payment_date_idx" ON "public"."pays" USING "btree" ("payment_date");

CREATE INDEX "payments_tenant_id_idx" ON "public"."pays" USING "btree" ("tenant_id");

CREATE INDEX "pays_profile_id_idx" ON "public"."pays" USING "btree" ("profile_id");

CREATE UNIQUE INDEX "profiles_parent_phone_uidx" ON "public"."profiles" USING "btree" ("parent_tenant_id", "phone_country_code", "phone") WHERE (("phone" IS NOT NULL) AND ("btrim"("phone") <> ''::"text") AND "is_phone_unique");

CREATE INDEX "profiles_parent_tenant_id_idx" ON "public"."profiles" USING "btree" ("parent_tenant_id");

CREATE INDEX "profiles_profile_type_idx" ON "public"."profiles" USING "btree" ("profile_type");

CREATE INDEX "recipient_profiles_name_idx" ON "public"."recipient_profiles" USING "btree" ("name");

CREATE INDEX "recipient_profiles_parent_tenant_id_idx" ON "public"."recipient_profiles" USING "btree" ("parent_tenant_id");

CREATE INDEX "recipient_profiles_tenant_id_idx" ON "public"."recipient_profiles" USING "btree" ("tenant_id");

CREATE UNIQUE INDEX "recipient_profiles_tenant_phone_uidx" ON "public"."recipient_profiles" USING "btree" ("tenant_id", "phone");

CREATE UNIQUE INDEX "sales_invoices_shop_order_id_uidx" ON "public"."bills" USING "btree" ("shop_order_id") WHERE ("shop_order_id" IS NOT NULL);

CREATE UNIQUE INDEX "uq_wallet_accounts_parent_book" ON "public"."cashbook_accounts" USING "btree" ("parent_tenant_id", "entity_type", "entity_id", "currency_code");
