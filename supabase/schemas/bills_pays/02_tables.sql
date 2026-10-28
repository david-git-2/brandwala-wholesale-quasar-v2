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
    "cashbook_point_id" bigint,
    "cashbook_point_pot_id" bigint,
    "quote_currency_code" "text" DEFAULT 'BDT'::"text" NOT NULL,
    "rate_date" "date",
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
    "global_stock_id" bigint,
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
    "line_kind" "text" DEFAULT 'stock'::"text" NOT NULL,
    "currency_code" "text" DEFAULT 'BDT'::"text" NOT NULL,
    "books_amount" numeric(12,2),
    CONSTRAINT "bill_lines_line_kind_check" CHECK (("line_kind" = ANY (ARRAY['stock'::"text", 'description'::"text", 'charge'::"text"]))),
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
    "global_stock_id" bigint,
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
    "bill_id" bigint,
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
    "ap_shipment_id" bigint,
    "ap_kind" "text",
    "document_kind" "public"."bill_document_kind" DEFAULT 'standard'::"public"."bill_document_kind" NOT NULL,
    "parent_bill_id" bigint,
    "from_profile_id" bigint,
    "to_profile_id" bigint,
    "settlement_kind" "public"."bill_settlement_kind",
    "source_type" "text",
    "source_id" "text",
    "source_key" "text",
    "currency_code" "text" DEFAULT 'BDT'::"text" NOT NULL,
    CONSTRAINT "bills_ap_kind_check" CHECK (("ap_kind" IS NULL) OR ("ap_kind" = ANY (ARRAY['vendor'::"text", 'cargo'::"text", 'local'::"text", 'material'::"text", 'freight'::"text", 'customs'::"text", 'handling'::"text", 'finance'::"text", 'other'::"text"]))),
    CONSTRAINT "bills_document_parent_check" CHECK (((("document_kind" = 'standard'::"public"."bill_document_kind") AND ("parent_bill_id" IS NULL)) OR (("document_kind" <> 'standard'::"public"."bill_document_kind") AND ("parent_bill_id" IS NOT NULL)))),
    CONSTRAINT "bills_from_to_distinct" CHECK ((("from_profile_id" IS NULL) OR ("to_profile_id" IS NULL) OR ("from_profile_id" <> "to_profile_id"))),
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
    "settlement_currency_code" "text" DEFAULT 'BDT'::"text" NOT NULL,
    "foreign_amount" numeric(12,2),
    "exchange_rate" numeric(15,6) DEFAULT 1.000000 NOT NULL,
    "quote_currency_code" "text" DEFAULT 'BDT'::"text" NOT NULL,
    "cashbook_point_id" bigint,
    "source_currency_code" "text",
    "transaction_rate" numeric(15,6),
    "source_amount" numeric(12,2),
    "cashbook_point_pot_id" bigint,
    CONSTRAINT "payments_amount_check" CHECK (("amount" >= (0)::numeric)),
    CONSTRAINT "pays_exchange_rate_positive" CHECK (("exchange_rate" > (0)::numeric)),
    CONSTRAINT "pays_settlement_fx_check" CHECK (((("settlement_currency_code" = 'BDT'::"text") AND ("foreign_amount" IS NULL) AND ("exchange_rate" = 1.000000)) OR (("settlement_currency_code" <> 'BDT'::"text") AND ("foreign_amount" IS NOT NULL) AND ("foreign_amount" > (0)::numeric) AND ("exchange_rate" > (0)::numeric)))),
    CONSTRAINT "pays_source_fx_check" CHECK (((("source_currency_code" IS NULL) AND ("transaction_rate" IS NULL) AND ("source_amount" IS NULL)) OR (("source_currency_code" IS NOT NULL) AND ("btrim"("source_currency_code") <> ''::"text") AND (("upper"("source_currency_code") = "upper"("settlement_currency_code") AND (("transaction_rate" IS NULL) OR ("transaction_rate" = 1.000000))) OR (("upper"("source_currency_code") <> "upper"("settlement_currency_code")) AND ("transaction_rate" > (0)::numeric)))))),
    CONSTRAINT "payments_method_check" CHECK ((("method" IS NULL) OR ("method" = ANY (ARRAY['cash'::"text", 'bank'::"text", 'bank_transfer'::"text", 'mobile_banking'::"text", 'bkash'::"text", 'nagad'::"text", 'other'::"text", 'cheque'::"text", 'rocket'::"text", 'upay'::"text", 'tap'::"text", 'card_pos'::"text", 'wire_transfer'::"text", 'paypal'::"text", 'stripe'::"text", 'letter_of_credit'::"text", 'cod'::"text", 'split'::"text", 'store_credit'::"text"])))),
    CONSTRAINT "pays_source_check" CHECK (("source" = ANY (ARRAY['customer_cash'::"text", 'bank'::"text", 'store_credit'::"text", 'courier_remittance'::"text", 'ap_payout'::"text"])))
);

ALTER TABLE "public"."pays" OWNER TO "postgres";

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

CREATE TABLE IF NOT EXISTS "public"."cashbook_points" (
    "id" bigint NOT NULL,
    "parent_tenant_id" bigint NOT NULL,
    "cashbook_account_id" bigint NOT NULL,
    "code" "text" NOT NULL,
    "name" "text" NOT NULL,
    "kind" "public"."cashbook_point_kind" DEFAULT 'drawer'::"public"."cashbook_point_kind" NOT NULL,
    "custodian_membership_id" bigint,
    "is_active" boolean DEFAULT true NOT NULL,
    "sort_order" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "cashbook_points_code_trimmed" CHECK (("btrim"("code") <> ''::"text")),
    CONSTRAINT "cashbook_points_name_trimmed" CHECK (("btrim"("name") <> ''::"text"))
);

ALTER TABLE "public"."cashbook_points" OWNER TO "postgres";

COMMENT ON TABLE "public"."cashbook_points" IS 'Place for tenant-held cash (till, safe, bank, fintech). No currency on the point; on-hand cash is cashbook_point_pots.';

CREATE TABLE IF NOT EXISTS "public"."cashbook_point_pots" (
    "id" bigint NOT NULL,
    "parent_tenant_id" bigint NOT NULL,
    "cashbook_point_id" bigint NOT NULL,
    "currency_code" "text" DEFAULT 'BDT'::"text" NOT NULL,
    "amount" numeric(18,4) DEFAULT 0.0000 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "cashbook_point_pots_amount_non_negative" CHECK (("amount" >= (0)::numeric)),
    CONSTRAINT "cashbook_point_pots_currency_code_trimmed" CHECK (("btrim"("currency_code") <> ''::"text"))
);

ALTER TABLE "public"."cashbook_point_pots" OWNER TO "postgres";

COMMENT ON TABLE "public"."cashbook_point_pots" IS 'On-hand cash at a point in one currency. FX rate is frozen on cashbook_entries, not on this row.';

CREATE TABLE IF NOT EXISTS "public"."books_exchange_rates" (
    "id" bigint NOT NULL,
    "parent_tenant_id" bigint NOT NULL,
    "base_currency_code" "text" DEFAULT 'BDT'::"text" NOT NULL,
    "quote_currency_code" "text" NOT NULL,
    "rate" numeric(18,6) NOT NULL,
    "rate_date" timestamp with time zone DEFAULT "now"() NOT NULL,
    "source" "text" DEFAULT 'manual'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "books_exchange_rates_rate_positive" CHECK (("rate" > (0)::numeric)),
    CONSTRAINT "books_exchange_rates_codes_trimmed" CHECK ((("btrim"("base_currency_code") <> ''::"text") AND ("btrim"("quote_currency_code") <> ''::"text"))),
    CONSTRAINT "books_exchange_rates_pair_distinct" CHECK (("upper"("base_currency_code") <> "upper"("quote_currency_code")))
);

ALTER TABLE "public"."books_exchange_rates" OWNER TO "postgres";

COMMENT ON TABLE "public"."books_exchange_rates" IS 'Default FX pick: rate = base (BDT) per 1 quote (e.g. GBP). Posted pays copy the pair onto the ledger line.';

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
    "line_meta",
    "line_kind",
    "currency_code",
    "books_amount"
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
    "cashbook_point_id" bigint,
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
    "customer_group_id" bigint,
    "operating_tenant_id" bigint,
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

ALTER TABLE "public"."cashbook_points" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."cashbook_points_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

ALTER TABLE "public"."cashbook_point_pots" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."cashbook_point_pots_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

ALTER TABLE "public"."books_exchange_rates" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."books_exchange_rates_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

ALTER TABLE ONLY "public"."bill_lines" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."global_invoice_items_id_seq"'::"regclass");

ALTER TABLE ONLY "public"."bills" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."global_invoices_id_seq"'::"regclass");

ALTER TABLE ONLY "public"."invoice_brands" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."invoice_brands_id_seq"'::"regclass");

ALTER TABLE ONLY "public"."pay_allocations" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."payment_allocations_id_seq"'::"regclass");

ALTER TABLE ONLY "public"."pay_instruments" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."global_payment_instruments_id_seq"'::"regclass");

ALTER TABLE ONLY "public"."pays" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."payments_id_seq"'::"regclass");

ALTER TABLE ONLY "public"."recipient_profiles" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."recipient_profiles_id_seq"'::"regclass");

ALTER TABLE ONLY "public"."sales_return_items" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."global_return_items_id_seq"'::"regclass");

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

ALTER TABLE ONLY "public"."cashbook_points"
    ADD CONSTRAINT "cashbook_points_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."cashbook_points"
    ADD CONSTRAINT "cashbook_points_account_code_key" UNIQUE ("cashbook_account_id", "code");

ALTER TABLE ONLY "public"."cashbook_point_pots"
    ADD CONSTRAINT "cashbook_point_pots_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."cashbook_point_pots"
    ADD CONSTRAINT "cashbook_point_pots_point_currency_key" UNIQUE ("cashbook_point_id", "currency_code");

ALTER TABLE ONLY "public"."books_exchange_rates"
    ADD CONSTRAINT "books_exchange_rates_pkey" PRIMARY KEY ("id");

CREATE INDEX "profiles_customer_group_id_idx" ON "public"."profiles" USING "btree" ("customer_group_id") WHERE ("profile_type" = 'customer'::"public"."profile_party_type");

CREATE INDEX "profiles_operating_tenant_id_idx" ON "public"."profiles" USING "btree" ("operating_tenant_id") WHERE ("profile_type" = 'customer'::"public"."profile_party_type");

CREATE UNIQUE INDEX "profiles_customer_parent_phone_uidx" ON "public"."profiles" USING "btree" ("parent_tenant_id", "phone_country_code", "phone") WHERE (("profile_type" = 'customer'::"public"."profile_party_type") AND ("phone" IS NOT NULL) AND ("btrim"("phone") <> ''::"text") AND "is_phone_unique");

CREATE INDEX "bills_profile_id_idx" ON "public"."bills" USING "btree" ("profile_id");

CREATE INDEX "bills_from_profile_id_idx" ON "public"."bills" USING "btree" ("from_profile_id");

CREATE INDEX "bills_to_profile_id_idx" ON "public"."bills" USING "btree" ("to_profile_id");

-- Active plug uniqueness: see bills_pays/05_money_spine.sql (uq_active_standard_bill)

CREATE INDEX "pay_allocations_bill_id_idx" ON "public"."pay_allocations" USING "btree" ("bill_id");

CREATE INDEX "pays_cashbook_point_id_idx" ON "public"."pays" USING "btree" ("cashbook_point_id") WHERE ("cashbook_point_id" IS NOT NULL);

CREATE INDEX "bills_parent_bill_id_idx" ON "public"."bills" USING "btree" ("parent_bill_id") WHERE ("parent_bill_id" IS NOT NULL);

CREATE INDEX "bills_ap_shipment_id_idx" ON "public"."bills" USING "btree" ("ap_shipment_id") WHERE ("invoice_type" = 'ap'::"public"."global_invoice_type");

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

CREATE INDEX "idx_sales_invoices_scoping" ON "public"."bills" USING "btree" ("parent_tenant_id", "issued_by_tenant_id", "invoice_status", "invoice_date");

CREATE INDEX "idx_sales_invoices_shop_order_id" ON "public"."bills" USING "btree" ("shop_order_id");

CREATE INDEX "idx_universal_wallet_ledger_lookup" ON "public"."cashbook_entries" USING "btree" ("tenant_id", "entity_type", "entity_id", "created_at" DESC, "id" DESC);

CREATE INDEX "idx_universal_wallet_ledger_source" ON "public"."cashbook_entries" USING "btree" ("source_type", "source_id");

CREATE INDEX "idx_uwl_operating_source" ON "public"."cashbook_entries" USING "btree" ("operating_tenant_id", "source_type", "source_id");

CREATE INDEX "idx_uwl_parent_book_lookup" ON "public"."cashbook_entries" USING "btree" ("parent_tenant_id", "entity_type", "entity_id", "created_at" DESC, "id" DESC);

CREATE INDEX "idx_uwl_parent_operating_created" ON "public"."cashbook_entries" USING "btree" ("parent_tenant_id", "operating_tenant_id", "created_at" DESC);

CREATE INDEX "idx_wallet_accounts_tenant_entity" ON "public"."cashbook_accounts" USING "btree" ("tenant_id", "entity_type", "entity_id");

CREATE INDEX "cashbook_points_parent_tenant_id_idx" ON "public"."cashbook_points" USING "btree" ("parent_tenant_id");

CREATE INDEX "cashbook_points_account_active_idx" ON "public"."cashbook_points" USING "btree" ("cashbook_account_id", "sort_order") WHERE ("is_active" = true);

CREATE INDEX "cashbook_entries_point_lookup_idx" ON "public"."cashbook_entries" USING "btree" ("cashbook_point_id", "created_at" DESC) WHERE ("cashbook_point_id" IS NOT NULL);

CREATE INDEX "cashbook_entries_pot_lookup_idx" ON "public"."cashbook_entries" USING "btree" ("cashbook_point_pot_id", "created_at" DESC) WHERE ("cashbook_point_pot_id" IS NOT NULL);

CREATE INDEX "cashbook_point_pots_parent_tenant_id_idx" ON "public"."cashbook_point_pots" USING "btree" ("parent_tenant_id");

CREATE INDEX "books_exchange_rates_lookup_idx" ON "public"."books_exchange_rates" USING "btree" ("parent_tenant_id", "quote_currency_code", "rate_date" DESC);

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
