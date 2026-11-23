-- Thrift domain tables (extracted from public.sql)

CREATE TABLE IF NOT EXISTS "public"."thrift_accounting_ledger" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "type" "public"."thrift_ledger_type" NOT NULL,
    "source" "public"."thrift_ledger_source" NOT NULL,
    "reference_id" bigint NOT NULL,
    "amount" numeric(12,2) NOT NULL,
    "date" timestamp with time zone DEFAULT "now"() NOT NULL,
    "inserted_by" "text" NOT NULL,
    "note" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "thrift_accounting_ledger_amount_check" CHECK (("amount" >= (0)::numeric))
);

ALTER TABLE "public"."thrift_accounting_ledger" OWNER TO "postgres";

CREATE SEQUENCE IF NOT EXISTS "public"."thrift_accounting_ledger_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE "public"."thrift_accounting_ledger_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."thrift_accounting_ledger_id_seq" OWNED BY "public"."thrift_accounting_ledger"."id";

CREATE TABLE IF NOT EXISTS "public"."thrift_barcodes" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "barcode_id" "text" NOT NULL,
    "status" "text" DEFAULT 'AVAILABLE'::"text" NOT NULL,
    "is_printed" smallint DEFAULT 0 NOT NULL,
    "inserted_by" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "thrift_barcodes_is_printed_check" CHECK (("is_printed" = ANY (ARRAY[0, 1])))
);

ALTER TABLE "public"."thrift_barcodes" OWNER TO "postgres";

CREATE SEQUENCE IF NOT EXISTS "public"."thrift_barcodes_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE "public"."thrift_barcodes_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."thrift_barcodes_id_seq" OWNED BY "public"."thrift_barcodes"."id";

CREATE TABLE IF NOT EXISTS "public"."thrift_boxes" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "shipment_id" bigint NOT NULL,
    "name" "text" NOT NULL,
    "weight" numeric(12,3),
    "received_weight" numeric(12,3),
    "inserted_by" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);

ALTER TABLE "public"."thrift_boxes" OWNER TO "postgres";

CREATE SEQUENCE IF NOT EXISTS "public"."thrift_boxes_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE "public"."thrift_boxes_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."thrift_boxes_id_seq" OWNED BY "public"."thrift_boxes"."id";

CREATE TABLE IF NOT EXISTS "public"."thrift_categories" (
    "id" bigint NOT NULL,
    "tenant_id" bigint,
    "name" "text" NOT NULL,
    "description" "text",
    "inserted_by" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "is_global" boolean DEFAULT false NOT NULL,
    CONSTRAINT "thrift_categories_scope_check" CHECK (((("is_global" = true) AND ("tenant_id" IS NULL)) OR (("is_global" = false) AND ("tenant_id" IS NOT NULL))))
);

ALTER TABLE "public"."thrift_categories" OWNER TO "postgres";

CREATE SEQUENCE IF NOT EXISTS "public"."thrift_categories_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE "public"."thrift_categories_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."thrift_categories_id_seq" OWNED BY "public"."thrift_categories"."id";

CREATE TABLE IF NOT EXISTS "public"."thrift_courier_providers" (
    "id" bigint NOT NULL,
    "tenant_id" bigint,
    "code" "text" NOT NULL,
    "name" "text" NOT NULL,
    "country_code" "text" DEFAULT 'BD'::"text" NOT NULL,
    "is_system" boolean DEFAULT false NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "sort_order" integer DEFAULT 100 NOT NULL,
    "meta" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "thrift_courier_providers_code_nonempty" CHECK (("length"(TRIM(BOTH FROM "code")) > 0)),
    CONSTRAINT "thrift_courier_providers_name_nonempty" CHECK (("length"(TRIM(BOTH FROM "name")) > 0)),
    CONSTRAINT "thrift_courier_providers_system_tenant_check" CHECK (((("is_system" = true) AND ("tenant_id" IS NULL)) OR (("is_system" = false) AND ("tenant_id" IS NOT NULL))))
);

ALTER TABLE "public"."thrift_courier_providers" OWNER TO "postgres";

COMMENT ON TABLE "public"."thrift_courier_providers" IS 'System (tenant_id null, is_system) BD catalog + tenant custom couriers for Online sales.';

COMMENT ON COLUMN "public"."thrift_courier_providers"."meta" IS 'JSONB extension bag for future extras (notes, website, support_phone, tracking_url_template). Not fee math.';

CREATE SEQUENCE IF NOT EXISTS "public"."thrift_courier_providers_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE "public"."thrift_courier_providers_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."thrift_courier_providers_id_seq" OWNED BY "public"."thrift_courier_providers"."id";

CREATE TABLE IF NOT EXISTS "public"."thrift_customers" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "name" "text" NOT NULL,
    "phone" "text" NOT NULL,
    "phone_normalized" "text" NOT NULL,
    "address" "text",
    "notes" "text",
    "inserted_by" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "secondary_phone" "text",
    "address_parts" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    CONSTRAINT "thrift_customers_phone_normalized_match_check" CHECK ((("phone_normalized" <> ''::"text") AND ("phone_normalized" = "public"."normalize_thrift_phone"("phone"))))
);

ALTER TABLE "public"."thrift_customers" OWNER TO "postgres";

COMMENT ON COLUMN "public"."thrift_customers"."secondary_phone" IS 'Optional alternate phone (not unique; primary phone_normalized remains upsert key).';

COMMENT ON COLUMN "public"."thrift_customers"."address_parts" IS 'BD location parts from static district/thana/postcode catalogs: { district, thana, post_code }. Freeform street stays in address.';

CREATE SEQUENCE IF NOT EXISTS "public"."thrift_customers_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE "public"."thrift_customers_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."thrift_customers_id_seq" OWNED BY "public"."thrift_customers"."id";

CREATE TABLE IF NOT EXISTS "public"."thrift_invoice_counters" (
    "tenant_id" bigint NOT NULL,
    "year_month" "text" NOT NULL,
    "last_value" bigint DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "thrift_invoice_counters_last_value_check" CHECK (("last_value" >= 0)),
    CONSTRAINT "thrift_invoice_counters_year_month_check" CHECK (("year_month" ~ '^\d{4}-\d{2}$'::"text"))
);

ALTER TABLE "public"."thrift_invoice_counters" OWNER TO "postgres";

CREATE TABLE IF NOT EXISTS "public"."thrift_invoice_items" (
    "id" bigint NOT NULL,
    "invoice_id" bigint NOT NULL,
    "stock_id" bigint NOT NULL,
    "quantity" integer NOT NULL,
    "sold_price" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "platform_fees" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "shipping_cost_paid_by_shop" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "item_status" "public"."thrift_item_status" DEFAULT 'SOLD'::"public"."thrift_item_status" NOT NULL,
    "return_reason" "text",
    "return_cost_charged_to_customer" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "return_cost_paid_by_shop" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "return_action" "public"."thrift_return_action",
    "net_profit" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "landed_unit_cost_at_sale" numeric(12,2) DEFAULT 0.00 NOT NULL,
    CONSTRAINT "thrift_invoice_items_platform_fees_check" CHECK (("platform_fees" >= (0)::numeric)),
    CONSTRAINT "thrift_invoice_items_quantity_check" CHECK (("quantity" > 0)),
    CONSTRAINT "thrift_invoice_items_return_cost_charged_to_customer_check" CHECK (("return_cost_charged_to_customer" >= (0)::numeric)),
    CONSTRAINT "thrift_invoice_items_return_cost_paid_by_shop_check" CHECK (("return_cost_paid_by_shop" >= (0)::numeric)),
    CONSTRAINT "thrift_invoice_items_shipping_cost_paid_by_shop_check" CHECK (("shipping_cost_paid_by_shop" >= (0)::numeric)),
    CONSTRAINT "thrift_invoice_items_sold_price_check" CHECK (("sold_price" >= (0)::numeric))
);

ALTER TABLE "public"."thrift_invoice_items" OWNER TO "postgres";

COMMENT ON TABLE "public"."thrift_invoice_items" IS 'LEGACY ARCHIVE — read-only (P21). Active sales use thrift_sales_invoice_items.';

CREATE SEQUENCE IF NOT EXISTS "public"."thrift_invoice_items_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE "public"."thrift_invoice_items_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."thrift_invoice_items_id_seq" OWNED BY "public"."thrift_invoice_items"."id";

CREATE TABLE IF NOT EXISTS "public"."thrift_invoices" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "invoice_number" "text" NOT NULL,
    "recipient_name" "text" NOT NULL,
    "address" "text" NOT NULL,
    "phone" "text" NOT NULL,
    "transaction_method" "public"."thrift_transaction_method" NOT NULL,
    "delivery_status" "public"."thrift_delivery_status" DEFAULT 'PENDING'::"public"."thrift_delivery_status" NOT NULL,
    "payment_status" "public"."thrift_payment_status" DEFAULT 'UNPAID'::"public"."thrift_payment_status" NOT NULL,
    "cod_charge" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "packing_charge" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "invoice_print_charge" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "shipping_charge_customer" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "total_invoice_amount" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "inserted_by" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "thrift_invoices_cod_charge_check" CHECK (("cod_charge" >= (0)::numeric)),
    CONSTRAINT "thrift_invoices_invoice_print_charge_check" CHECK (("invoice_print_charge" >= (0)::numeric)),
    CONSTRAINT "thrift_invoices_packing_charge_check" CHECK (("packing_charge" >= (0)::numeric)),
    CONSTRAINT "thrift_invoices_shipping_charge_customer_check" CHECK (("shipping_charge_customer" >= (0)::numeric)),
    CONSTRAINT "thrift_invoices_total_invoice_amount_check" CHECK (("total_invoice_amount" >= (0)::numeric))
);

ALTER TABLE "public"."thrift_invoices" OWNER TO "postgres";

COMMENT ON TABLE "public"."thrift_invoices" IS 'LEGACY ARCHIVE — read-only (P21). Active sales use thrift_sales_invoices.';

CREATE SEQUENCE IF NOT EXISTS "public"."thrift_invoices_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE "public"."thrift_invoices_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."thrift_invoices_id_seq" OWNED BY "public"."thrift_invoices"."id";

CREATE TABLE IF NOT EXISTS "public"."thrift_pricings" (
    "id" bigint NOT NULL,
    "stock_id" bigint NOT NULL,
    "cost_of_goods_sold" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "target_price" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "listed_unit_price" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "inserted_by" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "extra_expense_cost" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "is_listed_price_manual" boolean DEFAULT false,
    "markup_rate_override" numeric,
    CONSTRAINT "thrift_pricings_cost_of_goods_sold_check" CHECK (("cost_of_goods_sold" >= (0)::numeric)),
    CONSTRAINT "thrift_pricings_extra_expense_cost_check" CHECK (("extra_expense_cost" >= (0)::numeric)),
    CONSTRAINT "thrift_pricings_listed_price_check" CHECK (("listed_unit_price" >= (0)::numeric)),
    CONSTRAINT "thrift_pricings_target_price_check" CHECK (("target_price" >= (0)::numeric))
);

ALTER TABLE "public"."thrift_pricings" OWNER TO "postgres";

COMMENT ON COLUMN "public"."thrift_pricings"."cost_of_goods_sold" IS 'DEPRECATED (P22) — do not use as sale/report COGS. Source of truth: compute_thrift_landed_unit_cost + thrift_sales_invoice_items.landed_unit_cost_at_sale. Column retained until Wave 2+ drop.';

COMMENT ON COLUMN "public"."thrift_pricings"."target_price" IS 'DEPRECATED (P22) — prefer listed_unit_price + engine suggested sell. Column retained until Wave 2+ drop.';

COMMENT ON COLUMN "public"."thrift_pricings"."extra_expense_cost" IS 'DEPRECATED (P22) — not used by costing engine. Column retained until Wave 2+ drop.';

CREATE SEQUENCE IF NOT EXISTS "public"."thrift_pricings_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE "public"."thrift_pricings_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."thrift_pricings_id_seq" OWNED BY "public"."thrift_pricings"."id";

CREATE TABLE IF NOT EXISTS "public"."thrift_return_counters" (
    "tenant_id" bigint NOT NULL,
    "year_month" "text" NOT NULL,
    "last_value" bigint DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "thrift_return_counters_last_value_check" CHECK (("last_value" >= 0)),
    CONSTRAINT "thrift_return_counters_year_month_check" CHECK (("year_month" ~ '^\d{4}-\d{2}$'::"text"))
);

ALTER TABLE "public"."thrift_return_counters" OWNER TO "postgres";

CREATE TABLE IF NOT EXISTS "public"."thrift_sales_invoice_items" (
    "id" bigint NOT NULL,
    "invoice_id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "stock_id" bigint,
    "sell_price" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "discount_amount" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "final_price" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "quantity" integer DEFAULT 1 NOT NULL,
    "landed_unit_cost_at_sale" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "net_profit" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);

ALTER TABLE "public"."thrift_sales_invoice_items" OWNER TO "postgres";

CREATE SEQUENCE IF NOT EXISTS "public"."thrift_sales_invoice_items_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE "public"."thrift_sales_invoice_items_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."thrift_sales_invoice_items_id_seq" OWNED BY "public"."thrift_sales_invoice_items"."id";

CREATE TABLE IF NOT EXISTS "public"."thrift_sales_invoices" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "invoice_number" "text" NOT NULL,
    "date" timestamp with time zone DEFAULT "now"() NOT NULL,
    "payment_method" "text" DEFAULT 'CASH'::"text" NOT NULL,
    "payment_status" "text" DEFAULT 'PAID'::"text" NOT NULL,
    "total_invoice_amount" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "created_by" "text" DEFAULT ''::"text" NOT NULL,
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "customer_name" "text",
    "customer_phone" "text",
    "status" "text" DEFAULT 'ACTIVE'::"text" NOT NULL,
    "reverted_at" timestamp with time zone,
    "reverted_by" "text",
    "revert_reason" "text",
    "revert_notes" "text",
    "sale_channel" "text" DEFAULT 'IN_STORE'::"text" NOT NULL,
    "customer_id" bigint,
    "customer_address" "text",
    "courier_cod_amount" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "other_expense_amount" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "courier_amount" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "courier_paid_by" "text",
    "cod_expected" numeric(12,2),
    "cod_remitted_amount" numeric(12,2),
    "cod_remitted_at" timestamp with time zone,
    "cod_remittance_ref" "text",
    "delivery_status" "text",
    "courier_provider" "text",
    "cod_fee_amount" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "cod_fee_paid_by" "text",
    "packing_amount" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "packing_paid_by" "text",
    "return_courier_amount" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "close_reason" "text",
    "economics_closed_at" timestamp with time zone,
    "courier_provider_id" bigint,
    "meta" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "customer_secondary_phone" "text",
    "customer_address_parts" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "advance_amount" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "advance_note" "text",
    CONSTRAINT "thrift_sales_invoices_advance_amount_check" CHECK (("advance_amount" >= (0)::numeric)),
    CONSTRAINT "thrift_sales_invoices_close_reason_check" CHECK ((("close_reason" IS NULL) OR ("close_reason" = ANY (ARRAY['RTO'::"text", 'CUSTOMER_RETURN'::"text"])))),
    CONSTRAINT "thrift_sales_invoices_cod_expected_check" CHECK ((("cod_expected" IS NULL) OR ("cod_expected" >= (0)::numeric))),
    CONSTRAINT "thrift_sales_invoices_cod_fee_amount_check" CHECK (("cod_fee_amount" >= (0)::numeric)),
    CONSTRAINT "thrift_sales_invoices_cod_fee_paid_by_check" CHECK ((("cod_fee_paid_by" IS NULL) OR ("cod_fee_paid_by" = ANY (ARRAY['CUSTOMER'::"text", 'SHOP'::"text"])))),
    CONSTRAINT "thrift_sales_invoices_cod_fee_payer_consistency_check" CHECK (((("cod_fee_amount" > (0)::numeric) AND ("cod_fee_paid_by" IS NOT NULL)) OR (("cod_fee_amount" = (0)::numeric) AND ("cod_fee_paid_by" IS NULL)))),
    CONSTRAINT "thrift_sales_invoices_cod_remitted_amount_check" CHECK ((("cod_remitted_amount" IS NULL) OR ("cod_remitted_amount" >= (0)::numeric))),
    CONSTRAINT "thrift_sales_invoices_courier_amount_check" CHECK (("courier_amount" >= (0)::numeric)),
    CONSTRAINT "thrift_sales_invoices_courier_cod_amount_check" CHECK (("courier_cod_amount" >= (0)::numeric)),
    CONSTRAINT "thrift_sales_invoices_courier_paid_by_check" CHECK ((("courier_paid_by" IS NULL) OR ("courier_paid_by" = ANY (ARRAY['CUSTOMER'::"text", 'SHOP'::"text"])))),
    CONSTRAINT "thrift_sales_invoices_courier_payer_amount_check" CHECK (((("courier_amount" > (0)::numeric) AND ("courier_paid_by" IS NOT NULL)) OR (("courier_amount" = (0)::numeric) AND ("courier_paid_by" IS NULL)))),
    CONSTRAINT "thrift_sales_invoices_delivery_status_check" CHECK ((("delivery_status" IS NULL) OR ("delivery_status" = ANY (ARRAY['PENDING'::"text", 'READY'::"text", 'IN_TRANSIT'::"text", 'DELIVERED'::"text", 'RETURNED'::"text"])))),
    CONSTRAINT "thrift_sales_invoices_other_expense_amount_check" CHECK (("other_expense_amount" >= (0)::numeric)),
    CONSTRAINT "thrift_sales_invoices_packing_amount_check" CHECK (("packing_amount" >= (0)::numeric)),
    CONSTRAINT "thrift_sales_invoices_packing_paid_by_check" CHECK ((("packing_paid_by" IS NULL) OR ("packing_paid_by" = ANY (ARRAY['CUSTOMER'::"text", 'SHOP'::"text"])))),
    CONSTRAINT "thrift_sales_invoices_packing_payer_consistency_check" CHECK (((("packing_amount" > (0)::numeric) AND ("packing_paid_by" IS NOT NULL)) OR (("packing_amount" = (0)::numeric) AND ("packing_paid_by" IS NULL)))),
    CONSTRAINT "thrift_sales_invoices_payment_status_check" CHECK (("payment_status" = ANY (ARRAY['PAID'::"text", 'COD_PENDING'::"text", 'PARTIALLY_REFUNDED'::"text", 'REFUNDED'::"text", 'WRITTEN_OFF'::"text", 'UNPAID'::"text"]))),
    CONSTRAINT "thrift_sales_invoices_return_courier_amount_check" CHECK (("return_courier_amount" >= (0)::numeric)),
    CONSTRAINT "thrift_sales_invoices_sale_channel_check" CHECK (("sale_channel" = ANY (ARRAY['IN_STORE'::"text", 'ONLINE'::"text"]))),
    CONSTRAINT "thrift_sales_invoices_status_check" CHECK (("status" = ANY (ARRAY['ACTIVE'::"text", 'PARTIALLY_RETURNED'::"text", 'RETURNED'::"text", 'STAFF_MISTAKE'::"text"])))
);

ALTER TABLE "public"."thrift_sales_invoices" OWNER TO "postgres";

COMMENT ON COLUMN "public"."thrift_sales_invoices"."customer_name" IS 'Customer full name for thrift invoice';

COMMENT ON COLUMN "public"."thrift_sales_invoices"."customer_phone" IS 'Customer phone number for thrift invoice';

COMMENT ON COLUMN "public"."thrift_sales_invoices"."sale_channel" IS 'Hybrid desk channel: IN_STORE | ONLINE';

COMMENT ON COLUMN "public"."thrift_sales_invoices"."customer_id" IS 'Linked thrift_customers row when phone was present at sale';

COMMENT ON COLUMN "public"."thrift_sales_invoices"."customer_address" IS 'Sale-day address snapshot';

COMMENT ON COLUMN "public"."thrift_sales_invoices"."courier_cod_amount" IS 'DEPRECATED — use courier_amount. Retained for historical rows / reports.';

COMMENT ON COLUMN "public"."thrift_sales_invoices"."other_expense_amount" IS 'DEPRECATED — no longer written by create_thrift_sales_invoice.';

COMMENT ON COLUMN "public"."thrift_sales_invoices"."courier_amount" IS 'Courier fee amount (>= 0). Offline always 0.';

COMMENT ON COLUMN "public"."thrift_sales_invoices"."courier_paid_by" IS 'CUSTOMER | SHOP when courier_amount > 0; null when amount is 0.';

COMMENT ON COLUMN "public"."thrift_sales_invoices"."cod_expected" IS 'COD cash expected from courier (Online COD_PENDING). Null offline / paid-at-create.';

COMMENT ON COLUMN "public"."thrift_sales_invoices"."delivery_status" IS 'Parcel track for Online invoices. Null for Offline. Independent of payment_status.';

COMMENT ON COLUMN "public"."thrift_sales_invoices"."courier_provider" IS 'Online optional courier company name; Offline null.';

COMMENT ON COLUMN "public"."thrift_sales_invoices"."cod_fee_amount" IS 'Courier COD service fee (staff-entered ৳), not a stored %.';

COMMENT ON COLUMN "public"."thrift_sales_invoices"."packing_amount" IS 'Packing / print charge.';

COMMENT ON COLUMN "public"."thrift_sales_invoices"."return_courier_amount" IS 'RTO / no-pickup return courier billed to shop (post-pay returns use thrift_sales_returns).';

COMMENT ON COLUMN "public"."thrift_sales_invoices"."close_reason" IS 'RTO | CUSTOMER_RETURN when fully closed; null while open or partially returned.';

COMMENT ON COLUMN "public"."thrift_sales_invoices"."economics_closed_at" IS 'Last time thrift_sales_pnl_lines were written/updated for this invoice.';

COMMENT ON COLUMN "public"."thrift_sales_invoices"."courier_provider_id" IS 'Optional FK to thrift_courier_providers; name also snapshotted in courier_provider.';

COMMENT ON COLUMN "public"."thrift_sales_invoices"."meta" IS 'Optional Online extras (tracking_id, tracking_url). Not fee amounts.';

COMMENT ON COLUMN "public"."thrift_sales_invoices"."customer_secondary_phone" IS 'Snapshot of customer secondary phone at create.';

COMMENT ON COLUMN "public"."thrift_sales_invoices"."customer_address_parts" IS 'Snapshot of address_parts at create: { district, thana, post_code }.';

COMMENT ON COLUMN "public"."thrift_sales_invoices"."advance_amount" IS 'Customer advance collected at create (online COD only). Deducted from cod_expected; non-refundable. Offline always 0.';

COMMENT ON COLUMN "public"."thrift_sales_invoices"."advance_note" IS 'Optional note for advance (e.g. payment ref). Null when unused.';

CREATE SEQUENCE IF NOT EXISTS "public"."thrift_sales_invoices_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE "public"."thrift_sales_invoices_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."thrift_sales_invoices_id_seq" OWNED BY "public"."thrift_sales_invoices"."id";

CREATE TABLE IF NOT EXISTS "public"."thrift_sales_pnl_lines" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "invoice_id" bigint NOT NULL,
    "invoice_item_id" bigint NOT NULL,
    "stock_id" bigint NOT NULL,
    "inbound_shipment_id" bigint NOT NULL,
    "outcome" "text" NOT NULL,
    "return_id" bigint,
    "quantity" integer DEFAULT 1 NOT NULL,
    "sell_amount" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "allocated_shop_delivery" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "allocated_shop_cod_fee" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "allocated_shop_packing" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "allocated_return_courier" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "allocated_fees_total" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "cogs_is_loss" boolean DEFAULT false NOT NULL,
    "event_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "event_date" "date" DEFAULT (("now"() AT TIME ZONE 'UTC'::"text"))::"date" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "thrift_sales_pnl_lines_alloc_cod_check" CHECK (("allocated_shop_cod_fee" >= (0)::numeric)),
    CONSTRAINT "thrift_sales_pnl_lines_alloc_delivery_check" CHECK (("allocated_shop_delivery" >= (0)::numeric)),
    CONSTRAINT "thrift_sales_pnl_lines_alloc_packing_check" CHECK (("allocated_shop_packing" >= (0)::numeric)),
    CONSTRAINT "thrift_sales_pnl_lines_alloc_return_check" CHECK (("allocated_return_courier" >= (0)::numeric)),
    CONSTRAINT "thrift_sales_pnl_lines_fees_total_check" CHECK (("allocated_fees_total" = ((("allocated_shop_delivery" + "allocated_shop_cod_fee") + "allocated_shop_packing") + "allocated_return_courier"))),
    CONSTRAINT "thrift_sales_pnl_lines_outcome_check" CHECK (("outcome" = ANY (ARRAY['DELIVERED'::"text", 'RTO'::"text", 'CUSTOMER_RETURN'::"text"]))),
    CONSTRAINT "thrift_sales_pnl_lines_quantity_check" CHECK (("quantity" > 0)),
    CONSTRAINT "thrift_sales_pnl_lines_sell_amount_check" CHECK (("sell_amount" >= (0)::numeric))
);

ALTER TABLE "public"."thrift_sales_pnl_lines" OWNER TO "postgres";

COMMENT ON TABLE "public"."thrift_sales_pnl_lines" IS 'Per invoice-line economics fact for reports. COGS stays live via stock→inbound shipment.';

CREATE SEQUENCE IF NOT EXISTS "public"."thrift_sales_pnl_lines_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE "public"."thrift_sales_pnl_lines_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."thrift_sales_pnl_lines_id_seq" OWNED BY "public"."thrift_sales_pnl_lines"."id";

CREATE TABLE IF NOT EXISTS "public"."thrift_sales_return_items" (
    "id" bigint NOT NULL,
    "return_id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "invoice_item_id" bigint NOT NULL,
    "stock_id" bigint NOT NULL,
    "quantity" integer DEFAULT 1 NOT NULL,
    "condition" "text" NOT NULL,
    "refund_amount" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "thrift_sales_return_items_condition_check" CHECK (("condition" = ANY (ARRAY['SELLABLE'::"text", 'DAMAGED'::"text"]))),
    CONSTRAINT "thrift_sales_return_items_quantity_check" CHECK (("quantity" > 0)),
    CONSTRAINT "thrift_sales_return_items_refund_amount_check" CHECK (("refund_amount" >= (0)::numeric))
);

ALTER TABLE "public"."thrift_sales_return_items" OWNER TO "postgres";

CREATE SEQUENCE IF NOT EXISTS "public"."thrift_sales_return_items_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE "public"."thrift_sales_return_items_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."thrift_sales_return_items_id_seq" OWNED BY "public"."thrift_sales_return_items"."id";

CREATE TABLE IF NOT EXISTS "public"."thrift_sales_returns" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "invoice_id" bigint NOT NULL,
    "return_number" "text" NOT NULL,
    "status" "text" DEFAULT 'COMPLETED'::"text" NOT NULL,
    "refund_amount" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "return_courier_amount" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "notes" "text",
    "created_by" "text" DEFAULT ''::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "thrift_sales_returns_courier_amount_check" CHECK (("return_courier_amount" >= (0)::numeric)),
    CONSTRAINT "thrift_sales_returns_refund_amount_check" CHECK (("refund_amount" >= (0)::numeric)),
    CONSTRAINT "thrift_sales_returns_status_check" CHECK (("status" = 'COMPLETED'::"text"))
);

ALTER TABLE "public"."thrift_sales_returns" OWNER TO "postgres";

COMMENT ON TABLE "public"."thrift_sales_returns" IS 'Post-pay / post-delivery returns (partial or full). Not used for RTO no-pickup.';

CREATE SEQUENCE IF NOT EXISTS "public"."thrift_sales_returns_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE "public"."thrift_sales_returns_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."thrift_sales_returns_id_seq" OWNED BY "public"."thrift_sales_returns"."id";

CREATE TABLE IF NOT EXISTS "public"."thrift_settings" (
    "tenant_id" bigint NOT NULL,
    "default_origin_unit_price" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "hand_tag_unit_cost" numeric,
    "hand_tag_unit_currency_id" bigint,
    "sticker_unit_cost" numeric,
    "sticker_unit_currency_id" bigint,
    "marketing_tag_config" "jsonb" DEFAULT '{"show_logo": true, "brand_name": "", "show_tag_size": true, "show_brand_name": true, "show_core_sizes": true, "show_listed_sell": true, "show_barcode_text": true, "show_additional_sizes": true}'::"jsonb" NOT NULL,
    "return_window_days" integer DEFAULT 30 NOT NULL,
    CONSTRAINT "thrift_settings_return_window_days_check" CHECK (("return_window_days" >= 0)),
    CONSTRAINT "thrift_stock_settings_default_purchase_price_check" CHECK (("default_origin_unit_price" >= (0)::numeric))
);

ALTER TABLE "public"."thrift_settings" OWNER TO "postgres";

COMMENT ON COLUMN "public"."thrift_settings"."marketing_tag_config" IS 'Per-tenant marketing sticker layout settings.';

COMMENT ON COLUMN "public"."thrift_settings"."return_window_days" IS 'Customer RETURN eligibility window (days) from invoice date; 0 = no customer returns';

CREATE TABLE IF NOT EXISTS "public"."thrift_shelves" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "name" "text" NOT NULL,
    "location_bay" "text",
    "shelf_code" "text" NOT NULL,
    "inserted_by" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);

ALTER TABLE "public"."thrift_shelves" OWNER TO "postgres";

CREATE SEQUENCE IF NOT EXISTS "public"."thrift_shelves_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE "public"."thrift_shelves_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."thrift_shelves_id_seq" OWNED BY "public"."thrift_shelves"."id";

CREATE TABLE IF NOT EXISTS "public"."thrift_shipments" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "name" "text" NOT NULL,
    "cargo_conversion_rate" numeric(12,4),
    "cargo_rate" numeric(12,4),
    "product_conversion_rate" numeric(12,4),
    "inserted_by" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "purchase_currency_id" bigint NOT NULL,
    "cost_currency_id" bigint NOT NULL,
    "total_cargo_weight_kg" numeric,
    "labor_total_cost" numeric,
    "transportation_total_cost" numeric,
    "default_markup_rate" numeric,
    "washing_total_cost" numeric,
    "marketing_tag_config" "jsonb" DEFAULT '{"show_logo": true, "brand_name": "", "show_brand_name": true, "show_core_sizes": true, "show_listed_sell": true, "show_barcode_text": true}'::"jsonb" NOT NULL
);

ALTER TABLE "public"."thrift_shipments" OWNER TO "postgres";

COMMENT ON COLUMN "public"."thrift_shipments"."marketing_tag_config" IS 'Per-shipment marketing sticker layout: shop brand and field visibility.';

CREATE SEQUENCE IF NOT EXISTS "public"."thrift_shipments_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE "public"."thrift_shipments_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."thrift_shipments_id_seq" OWNED BY "public"."thrift_shipments"."id";

CREATE TABLE IF NOT EXISTS "public"."thrift_stock_images" (
    "id" bigint NOT NULL,
    "stock_id" bigint NOT NULL,
    "image_url" "text" NOT NULL,
    "is_primary" boolean DEFAULT false NOT NULL,
    "inserted_by" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "drive_file_id" "text"
);

ALTER TABLE "public"."thrift_stock_images" OWNER TO "postgres";

CREATE SEQUENCE IF NOT EXISTS "public"."thrift_stock_images_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE "public"."thrift_stock_images_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."thrift_stock_images_id_seq" OWNED BY "public"."thrift_stock_images"."id";

CREATE TABLE IF NOT EXISTS "public"."thrift_stock_measurements" (
    "stock_id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "bust_in" numeric(5,1),
    "waist_in" numeric(5,1),
    "hips_in" numeric(5,1),
    "length_in" numeric(5,1),
    "shoulder_width_in" numeric(5,1),
    "sleeve_length_in" numeric(5,1),
    "arm_circumference_in" numeric(5,1),
    "hem_width_in" numeric(5,1),
    "neck_opening_in" numeric(5,1),
    "sleeve_type" "text",
    "neckline" "text",
    "dress_style" "text",
    "fabric_stretch" "text",
    "lining" boolean,
    "closure_type" "text",
    "measurement_notes" "text",
    "inserted_by" "text" DEFAULT 'system'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);

ALTER TABLE "public"."thrift_stock_measurements" OWNER TO "postgres";

CREATE TABLE IF NOT EXISTS "public"."thrift_stocks" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "shipment_id" bigint NOT NULL,
    "name" "text",
    "brand_name" "text",
    "category_id" bigint,
    "type_id" bigint,
    "section" "public"."thrift_section",
    "shelf_id" bigint,
    "color" "text",
    "size" "text",
    "condition" "public"."thrift_condition",
    "stock_type" "public"."thrift_stock_type" DEFAULT 'SINGLE'::"public"."thrift_stock_type" NOT NULL,
    "quantity" integer DEFAULT 1 NOT NULL,
    "status" "public"."thrift_stock_status" DEFAULT 'AVAILABLE'::"public"."thrift_stock_status" NOT NULL,
    "note" "text",
    "inserted_by" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "box_id" bigint,
    "product_weight" numeric(12,3),
    "extra_weight" numeric(12,3),
    "origin_unit_price" numeric(12,2),
    "barcode" "text",
    "extra_origin_unit_price" numeric(12,2),
    "additional_charges_cost" numeric,
    "held_for_name" "text",
    "held_for_phone" "text",
    "held_for_phone_normalized" "text",
    "hold_note" "text",
    "held_by" "text",
    "held_at" timestamp with time zone,
    "hold_expires_at" timestamp with time zone,
    "deleted_at" timestamp with time zone,
    "deleted_by" "text",
    CONSTRAINT "thrift_stocks_extra_origin_purchase_expense_check" CHECK (("extra_origin_unit_price" >= (0)::numeric)),
    CONSTRAINT "thrift_stocks_extra_weight_check" CHECK (("extra_weight" >= (0)::numeric)),
    CONSTRAINT "thrift_stocks_origin_purchase_price_check" CHECK (("origin_unit_price" >= (0)::numeric)),
    CONSTRAINT "thrift_stocks_product_weight_check" CHECK (("product_weight" >= (0)::numeric)),
    CONSTRAINT "thrift_stocks_quantity_check" CHECK (("quantity" >= 0))
);

ALTER TABLE "public"."thrift_stocks" OWNER TO "postgres";

COMMENT ON COLUMN "public"."thrift_stocks"."name" IS 'Optional display name for the stock item.';

COMMENT ON COLUMN "public"."thrift_stocks"."held_for_phone_normalized" IS 'Digits-only hold key (normalize_thrift_phone). Required when status=RESERVED; sale convert requires invoice phone match.';

COMMENT ON COLUMN "public"."thrift_stocks"."hold_expires_at" IS 'Optional advisory expiry (v1). No auto-release job.';

CREATE SEQUENCE IF NOT EXISTS "public"."thrift_stocks_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE "public"."thrift_stocks_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."thrift_stocks_id_seq" OWNED BY "public"."thrift_stocks"."id";

CREATE TABLE IF NOT EXISTS "public"."thrift_types" (
    "id" bigint NOT NULL,
    "tenant_id" bigint,
    "name" "text" NOT NULL,
    "description" "text",
    "inserted_by" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "is_global" boolean DEFAULT false NOT NULL,
    "icon" "text",
    CONSTRAINT "thrift_types_scope_check" CHECK (((("is_global" = true) AND ("tenant_id" IS NULL)) OR (("is_global" = false) AND ("tenant_id" IS NOT NULL))))
);

ALTER TABLE "public"."thrift_types" OWNER TO "postgres";

CREATE SEQUENCE IF NOT EXISTS "public"."thrift_types_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE "public"."thrift_types_id_seq" OWNER TO "postgres";

ALTER SEQUENCE "public"."thrift_types_id_seq" OWNED BY "public"."thrift_types"."id";

ALTER TABLE ONLY "public"."thrift_accounting_ledger" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."thrift_accounting_ledger_id_seq"'::"regclass");

ALTER TABLE ONLY "public"."thrift_barcodes" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."thrift_barcodes_id_seq"'::"regclass");

ALTER TABLE ONLY "public"."thrift_boxes" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."thrift_boxes_id_seq"'::"regclass");

ALTER TABLE ONLY "public"."thrift_categories" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."thrift_categories_id_seq"'::"regclass");

ALTER TABLE ONLY "public"."thrift_courier_providers" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."thrift_courier_providers_id_seq"'::"regclass");

ALTER TABLE ONLY "public"."thrift_customers" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."thrift_customers_id_seq"'::"regclass");

ALTER TABLE ONLY "public"."thrift_invoice_items" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."thrift_invoice_items_id_seq"'::"regclass");

ALTER TABLE ONLY "public"."thrift_invoices" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."thrift_invoices_id_seq"'::"regclass");

ALTER TABLE ONLY "public"."thrift_pricings" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."thrift_pricings_id_seq"'::"regclass");

ALTER TABLE ONLY "public"."thrift_sales_invoice_items" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."thrift_sales_invoice_items_id_seq"'::"regclass");

ALTER TABLE ONLY "public"."thrift_sales_invoices" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."thrift_sales_invoices_id_seq"'::"regclass");

ALTER TABLE ONLY "public"."thrift_sales_pnl_lines" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."thrift_sales_pnl_lines_id_seq"'::"regclass");

ALTER TABLE ONLY "public"."thrift_sales_return_items" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."thrift_sales_return_items_id_seq"'::"regclass");

ALTER TABLE ONLY "public"."thrift_sales_returns" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."thrift_sales_returns_id_seq"'::"regclass");

ALTER TABLE ONLY "public"."thrift_shelves" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."thrift_shelves_id_seq"'::"regclass");

ALTER TABLE ONLY "public"."thrift_shipments" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."thrift_shipments_id_seq"'::"regclass");

ALTER TABLE ONLY "public"."thrift_stock_images" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."thrift_stock_images_id_seq"'::"regclass");

ALTER TABLE ONLY "public"."thrift_stocks" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."thrift_stocks_id_seq"'::"regclass");

ALTER TABLE ONLY "public"."thrift_types" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."thrift_types_id_seq"'::"regclass");

ALTER TABLE ONLY "public"."thrift_accounting_ledger"
    ADD CONSTRAINT "thrift_accounting_ledger_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."thrift_barcodes"
    ADD CONSTRAINT "thrift_barcodes_barcode_id_tenant_unique" UNIQUE ("tenant_id", "barcode_id");

ALTER TABLE ONLY "public"."thrift_barcodes"
    ADD CONSTRAINT "thrift_barcodes_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."thrift_boxes"
    ADD CONSTRAINT "thrift_boxes_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."thrift_categories"
    ADD CONSTRAINT "thrift_categories_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."thrift_courier_providers"
    ADD CONSTRAINT "thrift_courier_providers_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."thrift_customers"
    ADD CONSTRAINT "thrift_customers_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."thrift_customers"
    ADD CONSTRAINT "thrift_customers_tenant_phone_normalized_key" UNIQUE ("tenant_id", "phone_normalized");

ALTER TABLE ONLY "public"."thrift_invoice_counters"
    ADD CONSTRAINT "thrift_invoice_counters_pkey" PRIMARY KEY ("tenant_id", "year_month");

ALTER TABLE ONLY "public"."thrift_invoice_items"
    ADD CONSTRAINT "thrift_invoice_items_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."thrift_invoices"
    ADD CONSTRAINT "thrift_invoices_number_tenant_unique" UNIQUE ("tenant_id", "invoice_number");

ALTER TABLE ONLY "public"."thrift_invoices"
    ADD CONSTRAINT "thrift_invoices_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."thrift_pricings"
    ADD CONSTRAINT "thrift_pricings_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."thrift_pricings"
    ADD CONSTRAINT "thrift_pricings_stock_id_key" UNIQUE ("stock_id");

ALTER TABLE ONLY "public"."thrift_return_counters"
    ADD CONSTRAINT "thrift_return_counters_pkey" PRIMARY KEY ("tenant_id", "year_month");

ALTER TABLE ONLY "public"."thrift_sales_invoice_items"
    ADD CONSTRAINT "thrift_sales_invoice_items_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."thrift_sales_invoices"
    ADD CONSTRAINT "thrift_sales_invoices_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."thrift_sales_invoices"
    ADD CONSTRAINT "thrift_sales_invoices_tenant_num_key" UNIQUE ("tenant_id", "invoice_number");

ALTER TABLE ONLY "public"."thrift_sales_pnl_lines"
    ADD CONSTRAINT "thrift_sales_pnl_lines_invoice_item_key" UNIQUE ("invoice_item_id");

ALTER TABLE ONLY "public"."thrift_sales_pnl_lines"
    ADD CONSTRAINT "thrift_sales_pnl_lines_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."thrift_sales_return_items"
    ADD CONSTRAINT "thrift_sales_return_items_invoice_item_key" UNIQUE ("invoice_item_id");

ALTER TABLE ONLY "public"."thrift_sales_return_items"
    ADD CONSTRAINT "thrift_sales_return_items_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."thrift_sales_returns"
    ADD CONSTRAINT "thrift_sales_returns_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."thrift_sales_returns"
    ADD CONSTRAINT "thrift_sales_returns_tenant_number_key" UNIQUE ("tenant_id", "return_number");

ALTER TABLE ONLY "public"."thrift_shelves"
    ADD CONSTRAINT "thrift_shelves_code_tenant_unique" UNIQUE ("tenant_id", "shelf_code");

ALTER TABLE ONLY "public"."thrift_shelves"
    ADD CONSTRAINT "thrift_shelves_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."thrift_shipments"
    ADD CONSTRAINT "thrift_shipments_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."thrift_stock_images"
    ADD CONSTRAINT "thrift_stock_images_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."thrift_stock_measurements"
    ADD CONSTRAINT "thrift_stock_measurements_pkey" PRIMARY KEY ("stock_id");

ALTER TABLE ONLY "public"."thrift_settings"
    ADD CONSTRAINT "thrift_stock_settings_pkey" PRIMARY KEY ("tenant_id");

ALTER TABLE ONLY "public"."thrift_stocks"
    ADD CONSTRAINT "thrift_stocks_barcode_tenant_unique" UNIQUE ("tenant_id", "barcode");

ALTER TABLE ONLY "public"."thrift_stocks"
    ADD CONSTRAINT "thrift_stocks_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."thrift_types"
    ADD CONSTRAINT "thrift_types_pkey" PRIMARY KEY ("id");

CREATE INDEX "idx_thrift_courier_providers_picker" ON "public"."thrift_courier_providers" USING "btree" ("is_active", "sort_order", "name");

CREATE INDEX "idx_thrift_customers_tenant_name" ON "public"."thrift_customers" USING "btree" ("tenant_id", "name");

CREATE INDEX "idx_thrift_customers_tenant_updated" ON "public"."thrift_customers" USING "btree" ("tenant_id", "updated_at" DESC);

CREATE INDEX "idx_thrift_sales_invoice_items_invoice" ON "public"."thrift_sales_invoice_items" USING "btree" ("invoice_id");

CREATE INDEX "idx_thrift_sales_invoice_items_stock" ON "public"."thrift_sales_invoice_items" USING "btree" ("stock_id");

CREATE INDEX "idx_thrift_sales_invoices_courier_provider" ON "public"."thrift_sales_invoices" USING "btree" ("courier_provider_id") WHERE ("courier_provider_id" IS NOT NULL);

CREATE INDEX "idx_thrift_sales_invoices_tenant_close_reason" ON "public"."thrift_sales_invoices" USING "btree" ("tenant_id", "close_reason") WHERE ("close_reason" IS NOT NULL);

CREATE INDEX "idx_thrift_sales_invoices_tenant_customer" ON "public"."thrift_sales_invoices" USING "btree" ("tenant_id", "customer_id") WHERE ("customer_id" IS NOT NULL);

CREATE INDEX "idx_thrift_sales_invoices_tenant_date" ON "public"."thrift_sales_invoices" USING "btree" ("tenant_id", "date" DESC);

CREATE INDEX "idx_thrift_sales_invoices_tenant_delivery_status" ON "public"."thrift_sales_invoices" USING "btree" ("tenant_id", "delivery_status") WHERE ("delivery_status" IS NOT NULL);

CREATE INDEX "idx_thrift_sales_invoices_tenant_status" ON "public"."thrift_sales_invoices" USING "btree" ("tenant_id", "status");

CREATE INDEX "idx_thrift_sales_pnl_lines_invoice" ON "public"."thrift_sales_pnl_lines" USING "btree" ("invoice_id");

CREATE INDEX "idx_thrift_sales_pnl_lines_outcome" ON "public"."thrift_sales_pnl_lines" USING "btree" ("tenant_id", "outcome");

CREATE INDEX "idx_thrift_sales_pnl_lines_shipment" ON "public"."thrift_sales_pnl_lines" USING "btree" ("tenant_id", "inbound_shipment_id", "event_date" DESC);

CREATE INDEX "idx_thrift_sales_pnl_lines_tenant_event_date" ON "public"."thrift_sales_pnl_lines" USING "btree" ("tenant_id", "event_date" DESC);

CREATE INDEX "idx_thrift_sales_return_items_return" ON "public"."thrift_sales_return_items" USING "btree" ("return_id");

CREATE INDEX "idx_thrift_sales_return_items_stock" ON "public"."thrift_sales_return_items" USING "btree" ("stock_id");

CREATE INDEX "idx_thrift_sales_returns_invoice" ON "public"."thrift_sales_returns" USING "btree" ("invoice_id");

CREATE INDEX "idx_thrift_sales_returns_tenant_created" ON "public"."thrift_sales_returns" USING "btree" ("tenant_id", "created_at" DESC);

CREATE INDEX "idx_thrift_stock_measurements_bust" ON "public"."thrift_stock_measurements" USING "btree" ("tenant_id", "bust_in");

CREATE INDEX "idx_thrift_stock_measurements_hips" ON "public"."thrift_stock_measurements" USING "btree" ("tenant_id", "hips_in");

CREATE INDEX "idx_thrift_stock_measurements_waist" ON "public"."thrift_stock_measurements" USING "btree" ("tenant_id", "waist_in");

CREATE UNIQUE INDEX "thrift_categories_global_name_unique" ON "public"."thrift_categories" USING "btree" ("name") WHERE ("is_global" = true);

CREATE UNIQUE INDEX "thrift_categories_tenant_name_unique" ON "public"."thrift_categories" USING "btree" ("tenant_id", "name") WHERE ("is_global" = false);

CREATE UNIQUE INDEX "thrift_courier_providers_system_code_uidx" ON "public"."thrift_courier_providers" USING "btree" ("code") WHERE ("tenant_id" IS NULL);

CREATE UNIQUE INDEX "thrift_courier_providers_tenant_code_uidx" ON "public"."thrift_courier_providers" USING "btree" ("tenant_id", "code") WHERE ("tenant_id" IS NOT NULL);

CREATE INDEX "thrift_stock_images_stock_primary_idx" ON "public"."thrift_stock_images" USING "btree" ("stock_id") WHERE ("is_primary" = true);

CREATE INDEX "thrift_stocks_barcode_trgm_idx" ON "public"."thrift_stocks" USING "gin" ("barcode" "public"."gin_trgm_ops");

CREATE INDEX "thrift_stocks_brand_trgm_idx" ON "public"."thrift_stocks" USING "gin" ("brand_name" "public"."gin_trgm_ops");

CREATE INDEX "thrift_stocks_name_trgm_idx" ON "public"."thrift_stocks" USING "gin" ("name" "public"."gin_trgm_ops");

CREATE INDEX "thrift_stocks_tenant_condition_created_at_idx" ON "public"."thrift_stocks" USING "btree" ("tenant_id", "condition", "created_at" DESC);

CREATE INDEX "thrift_stocks_tenant_created_at_idx" ON "public"."thrift_stocks" USING "btree" ("tenant_id", "created_at" DESC);

CREATE INDEX "thrift_stocks_tenant_deleted_at_idx" ON "public"."thrift_stocks" USING "btree" ("tenant_id", "deleted_at") WHERE ("deleted_at" IS NULL);

CREATE INDEX "thrift_stocks_tenant_reserved_phone_idx" ON "public"."thrift_stocks" USING "btree" ("tenant_id", "held_for_phone_normalized") WHERE ("status" = 'RESERVED'::"public"."thrift_stock_status");

CREATE INDEX "thrift_stocks_tenant_status_created_at_idx" ON "public"."thrift_stocks" USING "btree" ("tenant_id", "status", "created_at" DESC);

CREATE UNIQUE INDEX "thrift_types_global_name_unique" ON "public"."thrift_types" USING "btree" ("name") WHERE ("is_global" = true);

CREATE UNIQUE INDEX "thrift_types_tenant_name_unique" ON "public"."thrift_types" USING "btree" ("tenant_id", "name") WHERE ("is_global" = false);

ALTER TABLE ONLY "public"."thrift_accounting_ledger"
    ADD CONSTRAINT "thrift_accounting_ledger_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."thrift_barcodes"
    ADD CONSTRAINT "thrift_barcodes_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."thrift_boxes"
    ADD CONSTRAINT "thrift_boxes_shipment_id_fkey" FOREIGN KEY ("shipment_id") REFERENCES "public"."thrift_shipments"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."thrift_boxes"
    ADD CONSTRAINT "thrift_boxes_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."thrift_categories"
    ADD CONSTRAINT "thrift_categories_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."thrift_courier_providers"
    ADD CONSTRAINT "thrift_courier_providers_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."thrift_customers"
    ADD CONSTRAINT "thrift_customers_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."thrift_invoice_counters"
    ADD CONSTRAINT "thrift_invoice_counters_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."thrift_invoice_items"
    ADD CONSTRAINT "thrift_invoice_items_invoice_id_fkey" FOREIGN KEY ("invoice_id") REFERENCES "public"."thrift_invoices"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."thrift_invoice_items"
    ADD CONSTRAINT "thrift_invoice_items_stock_id_fkey" FOREIGN KEY ("stock_id") REFERENCES "public"."thrift_stocks"("id");

ALTER TABLE ONLY "public"."thrift_invoices"
    ADD CONSTRAINT "thrift_invoices_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."thrift_pricings"
    ADD CONSTRAINT "thrift_pricings_stock_id_fkey" FOREIGN KEY ("stock_id") REFERENCES "public"."thrift_stocks"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."thrift_return_counters"
    ADD CONSTRAINT "thrift_return_counters_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."thrift_sales_invoice_items"
    ADD CONSTRAINT "thrift_sales_invoice_items_invoice_id_fkey" FOREIGN KEY ("invoice_id") REFERENCES "public"."thrift_sales_invoices"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."thrift_sales_invoice_items"
    ADD CONSTRAINT "thrift_sales_invoice_items_stock_id_fkey" FOREIGN KEY ("stock_id") REFERENCES "public"."thrift_stocks"("id") ON DELETE SET NULL;

ALTER TABLE ONLY "public"."thrift_sales_invoice_items"
    ADD CONSTRAINT "thrift_sales_invoice_items_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."thrift_sales_invoices"
    ADD CONSTRAINT "thrift_sales_invoices_courier_provider_id_fkey" FOREIGN KEY ("courier_provider_id") REFERENCES "public"."thrift_courier_providers"("id") ON DELETE SET NULL;

ALTER TABLE ONLY "public"."thrift_sales_invoices"
    ADD CONSTRAINT "thrift_sales_invoices_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "public"."thrift_customers"("id") ON DELETE SET NULL;

ALTER TABLE ONLY "public"."thrift_sales_invoices"
    ADD CONSTRAINT "thrift_sales_invoices_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."thrift_sales_pnl_lines"
    ADD CONSTRAINT "thrift_sales_pnl_lines_inbound_shipment_id_fkey" FOREIGN KEY ("inbound_shipment_id") REFERENCES "public"."thrift_shipments"("id") ON DELETE RESTRICT;

ALTER TABLE ONLY "public"."thrift_sales_pnl_lines"
    ADD CONSTRAINT "thrift_sales_pnl_lines_invoice_id_fkey" FOREIGN KEY ("invoice_id") REFERENCES "public"."thrift_sales_invoices"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."thrift_sales_pnl_lines"
    ADD CONSTRAINT "thrift_sales_pnl_lines_invoice_item_id_fkey" FOREIGN KEY ("invoice_item_id") REFERENCES "public"."thrift_sales_invoice_items"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."thrift_sales_pnl_lines"
    ADD CONSTRAINT "thrift_sales_pnl_lines_return_id_fkey" FOREIGN KEY ("return_id") REFERENCES "public"."thrift_sales_returns"("id") ON DELETE SET NULL;

ALTER TABLE ONLY "public"."thrift_sales_pnl_lines"
    ADD CONSTRAINT "thrift_sales_pnl_lines_stock_id_fkey" FOREIGN KEY ("stock_id") REFERENCES "public"."thrift_stocks"("id") ON DELETE RESTRICT;

ALTER TABLE ONLY "public"."thrift_sales_pnl_lines"
    ADD CONSTRAINT "thrift_sales_pnl_lines_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."thrift_sales_return_items"
    ADD CONSTRAINT "thrift_sales_return_items_invoice_item_id_fkey" FOREIGN KEY ("invoice_item_id") REFERENCES "public"."thrift_sales_invoice_items"("id") ON DELETE RESTRICT;

ALTER TABLE ONLY "public"."thrift_sales_return_items"
    ADD CONSTRAINT "thrift_sales_return_items_return_id_fkey" FOREIGN KEY ("return_id") REFERENCES "public"."thrift_sales_returns"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."thrift_sales_return_items"
    ADD CONSTRAINT "thrift_sales_return_items_stock_id_fkey" FOREIGN KEY ("stock_id") REFERENCES "public"."thrift_stocks"("id") ON DELETE RESTRICT;

ALTER TABLE ONLY "public"."thrift_sales_return_items"
    ADD CONSTRAINT "thrift_sales_return_items_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."thrift_sales_returns"
    ADD CONSTRAINT "thrift_sales_returns_invoice_id_fkey" FOREIGN KEY ("invoice_id") REFERENCES "public"."thrift_sales_invoices"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."thrift_sales_returns"
    ADD CONSTRAINT "thrift_sales_returns_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."thrift_settings"
    ADD CONSTRAINT "thrift_settings_hand_tag_unit_currency_id_fkey" FOREIGN KEY ("hand_tag_unit_currency_id") REFERENCES "public"."global_currencies"("id") ON DELETE SET NULL;

ALTER TABLE ONLY "public"."thrift_settings"
    ADD CONSTRAINT "thrift_settings_sticker_unit_currency_id_fkey" FOREIGN KEY ("sticker_unit_currency_id") REFERENCES "public"."global_currencies"("id") ON DELETE SET NULL;

ALTER TABLE ONLY "public"."thrift_settings"
    ADD CONSTRAINT "thrift_settings_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."thrift_shelves"
    ADD CONSTRAINT "thrift_shelves_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."thrift_shipments"
    ADD CONSTRAINT "thrift_shipments_cost_currency_id_fkey" FOREIGN KEY ("cost_currency_id") REFERENCES "public"."global_currencies"("id");

ALTER TABLE ONLY "public"."thrift_shipments"
    ADD CONSTRAINT "thrift_shipments_purchase_currency_id_fkey" FOREIGN KEY ("purchase_currency_id") REFERENCES "public"."global_currencies"("id");

ALTER TABLE ONLY "public"."thrift_shipments"
    ADD CONSTRAINT "thrift_shipments_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."thrift_stock_images"
    ADD CONSTRAINT "thrift_stock_images_stock_id_fkey" FOREIGN KEY ("stock_id") REFERENCES "public"."thrift_stocks"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."thrift_stock_measurements"
    ADD CONSTRAINT "thrift_stock_measurements_stock_id_fkey" FOREIGN KEY ("stock_id") REFERENCES "public"."thrift_stocks"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."thrift_stocks"
    ADD CONSTRAINT "thrift_stocks_box_id_fkey" FOREIGN KEY ("box_id") REFERENCES "public"."thrift_boxes"("id") ON DELETE SET NULL;

ALTER TABLE ONLY "public"."thrift_stocks"
    ADD CONSTRAINT "thrift_stocks_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "public"."thrift_categories"("id");

ALTER TABLE ONLY "public"."thrift_stocks"
    ADD CONSTRAINT "thrift_stocks_shelf_id_fkey" FOREIGN KEY ("shelf_id") REFERENCES "public"."thrift_shelves"("id");

ALTER TABLE ONLY "public"."thrift_stocks"
    ADD CONSTRAINT "thrift_stocks_shipment_id_fkey" FOREIGN KEY ("shipment_id") REFERENCES "public"."thrift_shipments"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."thrift_stocks"
    ADD CONSTRAINT "thrift_stocks_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."thrift_stocks"
    ADD CONSTRAINT "thrift_stocks_type_id_fkey" FOREIGN KEY ("type_id") REFERENCES "public"."thrift_types"("id");

ALTER TABLE ONLY "public"."thrift_types"
    ADD CONSTRAINT "thrift_types_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;
