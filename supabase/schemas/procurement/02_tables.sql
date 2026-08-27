-- Extracted from supabase/schemas/public.sql (procurement/stock/costing). Move-only.

CREATE TABLE IF NOT EXISTS "public"."global_shipment_items" (
    "id" bigint NOT NULL,
    "shipment_id" bigint NOT NULL,
    "product_id" bigint,
    "name" "text" NOT NULL,
    "ordered_quantity" integer NOT NULL,
    "image_url" "text",
    "add_method" "public"."global_shipment_item_add_method" DEFAULT 'manual'::"public"."global_shipment_item_add_method" NOT NULL,
    "purchase_price" numeric DEFAULT 0.0 NOT NULL,
    "product_weight" numeric DEFAULT 0.0 NOT NULL,
    "package_weight" numeric DEFAULT 0.0 NOT NULL,
    "barcode" "text",
    "product_code" "text",
    "source_child_tenant_id" bigint,
    "source_type" "text",
    "source_id" bigint,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "vendor_id" bigint,
    "sort_order" integer DEFAULT 0 NOT NULL,
    "landed_cost_bdt" numeric,
    "received_quantity" integer,
    "section_id" bigint,
    CONSTRAINT "global_shipment_items_name_not_blank" CHECK (("length"(TRIM(BOTH FROM "name")) > 0)),
    CONSTRAINT "global_shipment_items_ordered_quantity_check" CHECK (("ordered_quantity" >= 0)),
    CONSTRAINT "global_shipment_items_received_quantity_check" CHECK ((("received_quantity" IS NULL) OR ("received_quantity" >= 0)))
);


ALTER TABLE "public"."global_shipment_items" OWNER TO "postgres";


COMMENT ON COLUMN "public"."global_shipment_items"."landed_cost_bdt" IS 'Authoritative per-unit landed BDT. Written only by finalize/revision stamp RPCs. Null while draft.';



CREATE TABLE IF NOT EXISTS "public"."global_shipment_sections" (
    "id" bigint NOT NULL,
    "parent_tenant_id" bigint NOT NULL,
    "shipment_id" bigint NOT NULL,
    "vendor_id" bigint NOT NULL,
    "title" "text" NOT NULL,
    "sort_order" integer DEFAULT 0 NOT NULL,
    "metadata" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "global_shipment_sections_title_not_blank" CHECK (("length"(TRIM(BOTH FROM "title")) > 0))
);


ALTER TABLE "public"."global_shipment_sections" OWNER TO "postgres";



CREATE TABLE IF NOT EXISTS "public"."shipment_items" (
    "id" bigint NOT NULL,
    "shipment_id" bigint NOT NULL,
    "name" "text",
    "quantity" integer DEFAULT 0 NOT NULL,
    "barcode" "text",
    "product_code" "text",
    "product_id" bigint,
    "image_url" "text",
    "product_weight" numeric(12,3),
    "package_weight" numeric(12,3),
    "price_gbp" numeric(12,2),
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "order_id" bigint,
    "method" "text" DEFAULT 'manual'::"text" NOT NULL,
    "marker_tag" "text",
    "inspected" boolean DEFAULT false NOT NULL,
    "receiving_splits" "jsonb",
    "cost_bdt" numeric(12,2),
    "source_child_tenant_id" bigint,
    "source_type" "text",
    "source_id" bigint,
    "sort_order" integer DEFAULT 0 NOT NULL,
    CONSTRAINT "shipment_items_marker_tag_check" CHECK ((("marker_tag" = ANY (ARRAY['price_reviewed'::"text", 'issue'::"text", 'done'::"text"])) OR ("marker_tag" IS NULL))),
    CONSTRAINT "shipment_items_method_check" CHECK (("method" = ANY (ARRAY['order'::"text", 'costing'::"text", 'manual'::"text"]))),
    CONSTRAINT "shipment_items_quantity_check" CHECK (("quantity" >= 0)),
    CONSTRAINT "shipment_items_source_type_check" CHECK (("source_type" = ANY (ARRAY['order_item'::"text", 'costing_item'::"text", 'manual'::"text"])))
);


ALTER TABLE "public"."shipment_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."shipment_progress_flows" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "name" "text" NOT NULL,
    "slug" "text" NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "is_default" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."shipment_progress_flows" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."shipments" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "name" "text" NOT NULL,
    "product_conversion_rate" numeric(12,4),
    "cargo_conversion_rate" numeric(12,4),
    "cargo_rate" numeric(12,4),
    "received_weight" numeric(12,3),
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "status" "text" DEFAULT 'Draft'::"text" NOT NULL,
    "inventory_added" boolean DEFAULT false NOT NULL,
    "market_code" "text",
    "tenant_shipment_id" bigint NOT NULL,
    "transaction_rate" numeric(12,4),
    "shipment_type" "text" DEFAULT 'international'::"text" NOT NULL,
    CONSTRAINT "shipments_name_not_blank" CHECK (("length"(TRIM(BOTH FROM "name")) > 0)),
    CONSTRAINT "shipments_shipment_type_check" CHECK (("shipment_type" = ANY (ARRAY['local'::"text", 'international'::"text"]))),
    CONSTRAINT "shipments_status_check" CHECK (("status" = ANY (ARRAY['Draft'::"text", 'Order Placed'::"text", 'Proforma Generated'::"text", 'Payment Done'::"text", 'Delivery Date Received'::"text", 'Uk Warehouse Delivery Received'::"text", 'Air Shipment Date Set'::"text", 'Airport Arrival'::"text", 'Airport Released'::"text", 'Warehouse Received'::"text", 'Added to Inventory'::"text"])))
);


ALTER TABLE "public"."shipments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."global_shipments" (
    "id" bigint NOT NULL,
    "parent_tenant_id" bigint NOT NULL,
    "name" "text" NOT NULL,
    "tenant_shipment_id" integer,
    "type" "public"."global_shipment_type" DEFAULT 'international'::"public"."global_shipment_type" NOT NULL,
    "status" "text" DEFAULT 'draft'::"text" NOT NULL,
    "shipment_purchase_currency_id" bigint,
    "shipment_cost_currency_id" bigint,
    "received_weight" numeric,
    "stock_ready" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "received_date" "date",
    "cargo_invoice_total" numeric,
    "purchase_invoice_total" numeric,
    "assigned_child_tenant_id" bigint,
    "vendor_id" bigint,
    "cargo_company_id" bigint,
    "total_weight_kg" numeric,
    "inventory_added" boolean DEFAULT false NOT NULL,
    "progress_tag_id" bigint,
    "public_tracking_token" "text",
    "progress_flow_id" bigint,
    CONSTRAINT "global_shipments_name_not_blank" CHECK (("length"(TRIM(BOTH FROM "name")) > 0)),
    CONSTRAINT "global_shipments_status_check" CHECK (("status" = ANY (ARRAY['draft'::"text", 'in_transit'::"text", 'received'::"text", 'cancelled'::"text"])))
);


ALTER TABLE "public"."global_shipments" OWNER TO "postgres";


COMMENT ON COLUMN "public"."global_shipments"."total_weight_kg" IS 'Cargo invoice weight (kg). Plan name for live received_weight — dual-written.';



COMMENT ON COLUMN "public"."global_shipments"."inventory_added" IS 'True after finalize posts stock. Plan name for live stock_ready — dual-written.';



COMMENT ON COLUMN "public"."global_shipments"."progress_tag_id" IS 'Denormalized current shipment_progress tag for list speed. SSOT remains entity_tags.';



COMMENT ON COLUMN "public"."global_shipments"."public_tracking_token" IS 'Random token for unauthenticated public tracking page. NULL = no link generated yet.';



CREATE TABLE IF NOT EXISTS "public"."vendors" (
    "id" bigint NOT NULL,
    "name" "text" NOT NULL,
    "code" "text" NOT NULL,
    "market_code" "text" NOT NULL,
    "tenant_id" bigint,
    "email" "text",
    "phone" "text",
    "address" "text",
    "website" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "parent_tenant_id" bigint,
    "is_default" boolean DEFAULT false NOT NULL,
    CONSTRAINT "vendors_code_not_blank" CHECK (("length"(TRIM(BOTH FROM "code")) > 0)),
    CONSTRAINT "vendors_market_code_not_blank" CHECK (("length"(TRIM(BOTH FROM "market_code")) > 0)),
    CONSTRAINT "vendors_name_not_blank" CHECK (("length"(TRIM(BOTH FROM "name")) > 0))
);


ALTER TABLE "public"."vendors" OWNER TO "postgres";


COMMENT ON COLUMN "public"."vendors"."is_default" IS 'True for the tenant system default vendor (code DEFAULT). At most one per tenant_id.';



CREATE TABLE IF NOT EXISTS "public"."global_shipment_cost_entries" (
    "id" bigint NOT NULL,
    "parent_tenant_id" bigint NOT NULL,
    "shipment_id" bigint NOT NULL,
    "cost_type" "public"."global_shipment_cost_type" NOT NULL,
    "amount" numeric NOT NULL,
    "currency_id" bigint,
    "exchange_rate" numeric DEFAULT 1.0 NOT NULL,
    "payment_source" "text",
    "entity_type" "text",
    "entity_id" bigint,
    "allocation" "text",
    "metadata" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "settled_at" timestamp with time zone,
    "settlement_ledger_id" "uuid",
    "section_id" bigint,
    CONSTRAINT "global_shipment_cost_entries_amount_check" CHECK (("amount" >= (0)::numeric)),
    CONSTRAINT "global_shipment_cost_entries_exchange_rate_check" CHECK (("exchange_rate" > (0)::numeric)),
    CONSTRAINT "global_shipment_cost_entries_payment_source_check" CHECK ((("payment_source" IS NULL) OR ("payment_source" = ANY (ARRAY['cash'::"text", 'credit'::"text", 'wallet'::"text"]))))
);


ALTER TABLE "public"."global_shipment_cost_entries" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."stock_locations" (
    "id" bigint NOT NULL,
    "parent_tenant_id" bigint NOT NULL,
    "code" "text" NOT NULL,
    "name" "text" NOT NULL,
    "kind" "public"."stock_location_kind" DEFAULT 'box'::"public"."stock_location_kind" NOT NULL,
    "is_default" boolean DEFAULT false NOT NULL,
    "is_pickable" boolean DEFAULT true NOT NULL,
    "sort_order" integer DEFAULT 0 NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "parent_location_id" bigint,
    CONSTRAINT "stock_locations_code_not_blank" CHECK (("length"(TRIM(BOTH FROM "code")) > 0)),
    CONSTRAINT "stock_locations_name_not_blank" CHECK (("length"(TRIM(BOTH FROM "name")) > 0))
);


ALTER TABLE "public"."stock_locations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."shipment_investments" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "shipment_id" bigint,
    "investor_id" bigint NOT NULL,
    "invested_amount" numeric(12,2) DEFAULT 0 NOT NULL,
    "actual_profit" numeric(12,2) DEFAULT 0 NOT NULL,
    "status" "public"."shipment_investment_status" DEFAULT 'active'::"public"."shipment_investment_status" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "cost_share_pct" numeric(5,2),
    "allocated_cost" numeric(12,2) DEFAULT 0 NOT NULL,
    "computed_profit" numeric(12,2) DEFAULT 0 NOT NULL,
    "profit_status" "text" DEFAULT 'open'::"text" NOT NULL,
    "global_shipment_id" bigint,
    CONSTRAINT "shipment_investments_cost_share_pct_check" CHECK ((("cost_share_pct" IS NULL) OR (("cost_share_pct" >= (0)::numeric) AND ("cost_share_pct" <= (100)::numeric)))),
    CONSTRAINT "shipment_investments_invested_amount_check" CHECK (("invested_amount" >= (0)::numeric)),
    CONSTRAINT "shipment_investments_profit_status_check" CHECK (("profit_status" = ANY (ARRAY['open'::"text", 'partial'::"text", 'realized'::"text"])))
);


ALTER TABLE "public"."shipment_investments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."product_based_costing_backlog_items" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "billing_profile_id" bigint NOT NULL,
    "product_id" bigint NOT NULL,
    "open_quantity" integer NOT NULL,
    "name" "text" NOT NULL,
    "image_url" "text",
    "barcode" "text",
    "product_code" "text",
    "price_gbp" numeric,
    "product_weight" numeric,
    "package_weight" numeric,
    "note" "text",
    "last_costing_file_id" bigint,
    "last_costing_item_id" bigint,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "product_based_costing_backlog_items_open_quantity_check" CHECK (("open_quantity" > 0))
);


ALTER TABLE "public"."product_based_costing_backlog_items" OWNER TO "postgres";


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



CREATE TABLE IF NOT EXISTS "public"."global_shipment_boxes" (
    "id" bigint NOT NULL,
    "parent_tenant_id" bigint NOT NULL,
    "shipment_id" bigint NOT NULL,
    "box_number" "text" NOT NULL,
    "weight_kg" numeric NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "global_shipment_boxes_weight_kg_check" CHECK (("weight_kg" >= (0)::numeric))
);


ALTER TABLE "public"."global_shipment_boxes" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."global_shipment_boxes_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."global_shipment_boxes_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."global_shipment_boxes_id_seq" OWNED BY "public"."global_shipment_boxes"."id";



ALTER TABLE "public"."global_shipment_cost_entries" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."global_shipment_cost_entries_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE SEQUENCE IF NOT EXISTS "public"."global_shipment_items_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."global_shipment_items_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."global_shipment_items_id_seq" OWNED BY "public"."global_shipment_items"."id";



CREATE SEQUENCE IF NOT EXISTS "public"."global_shipment_sections_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."global_shipment_sections_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."global_shipment_sections_id_seq" OWNED BY "public"."global_shipment_sections"."id";



CREATE SEQUENCE IF NOT EXISTS "public"."global_shipments_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."global_shipments_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."global_shipments_id_seq" OWNED BY "public"."global_shipments"."id";



CREATE TABLE IF NOT EXISTS "public"."global_stock_types" (
    "id" bigint NOT NULL,
    "parent_tenant_id" bigint,
    "description" "text" NOT NULL,
    "is_sellable" boolean DEFAULT true NOT NULL,
    "sort_order" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "global_stock_types_desc_not_blank" CHECK (("length"(TRIM(BOTH FROM "description")) > 0))
);


ALTER TABLE "public"."global_stock_types" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."global_stock_types_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."global_stock_types_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."global_stock_types_id_seq" OWNED BY "public"."global_stock_types"."id";



CREATE TABLE IF NOT EXISTS "public"."global_stocks" (
    "id" bigint NOT NULL,
    "parent_tenant_id" bigint NOT NULL,
    "shipment_item_id" bigint NOT NULL,
    "stock_type_id" bigint,
    "quantity" integer DEFAULT 0 NOT NULL,
    "is_usable" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "availability" "public"."stock_availability" DEFAULT 'sellable'::"public"."stock_availability" NOT NULL,
    "location_id" bigint,
    "grade_tag_id" bigint,
    CONSTRAINT "global_stocks_quantity_check" CHECK (("quantity" >= 0))
);


ALTER TABLE "public"."global_stocks" OWNER TO "postgres";


COMMENT ON COLUMN "public"."global_stocks"."availability" IS 'Stock pool availability state for warehouse & ATP calculation.';



COMMENT ON COLUMN "public"."global_stocks"."location_id" IS 'Warehouse bin / location where stock is located.';



CREATE SEQUENCE IF NOT EXISTS "public"."global_stocks_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."global_stocks_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."global_stocks_id_seq" OWNED BY "public"."global_stocks"."id";



ALTER TABLE "public"."product_based_costing_backlog_items" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."product_based_costing_backlog_items_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."product_based_costing_files" (
    "id" bigint NOT NULL,
    "tenant_id" bigint,
    "name" "text",
    "order_for" "text",
    "note" "text",
    "cargo_rate_kg_gbp" numeric(12,4),
    "profit_rate" numeric(12,4),
    "conversion_rate" numeric(12,6),
    "status" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "invoice_id" bigint,
    "vendor_code" "text",
    "market_code" "text",
    "default_shipment_id" bigint,
    "vendor_id" bigint,
    "billing_profile_id" bigint
);


ALTER TABLE "public"."product_based_costing_files" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."product_based_costing_files_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."product_based_costing_files_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."product_based_costing_files_id_seq" OWNED BY "public"."product_based_costing_files"."id";



CREATE TABLE IF NOT EXISTS "public"."product_based_costing_items" (
    "id" bigint NOT NULL,
    "product_based_costing_file_id" bigint,
    "name" "text",
    "image_url" "text",
    "quantity" numeric(12,3),
    "barcode" "text",
    "product_code" "text",
    "web_link" "text",
    "price_gbp" numeric(12,2),
    "product_weight" numeric(12,3),
    "package_weight" numeric(12,3),
    "offer_price" numeric(12,2),
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "product_id" bigint,
    "note" "text",
    "input_type" "text",
    "vendor_code" "text",
    "market_code" "text",
    "brand" "text",
    "assigned_shipment_id" bigint,
    "vendor_id" bigint,
    "is_offer_price_manual" boolean DEFAULT false NOT NULL,
    "confirmed_quantity" integer,
    CONSTRAINT "product_based_costing_items_input_type_check" CHECK ((("input_type" = ANY (ARRAY['manual'::"text", 'product_list'::"text"])) OR ("input_type" IS NULL)))
);


ALTER TABLE "public"."product_based_costing_items" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."product_based_costing_items_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."product_based_costing_items_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."product_based_costing_items_id_seq" OWNED BY "public"."product_based_costing_items"."id";



CREATE SEQUENCE IF NOT EXISTS "public"."shipment_investments_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."shipment_investments_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."shipment_investments_id_seq" OWNED BY "public"."shipment_investments"."id";



CREATE SEQUENCE IF NOT EXISTS "public"."shipment_items_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."shipment_items_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."shipment_items_id_seq" OWNED BY "public"."shipment_items"."id";



CREATE TABLE IF NOT EXISTS "public"."shipment_progress_flow_stages" (
    "id" bigint NOT NULL,
    "flow_id" bigint NOT NULL,
    "tag_id" bigint NOT NULL,
    "sort_order" integer DEFAULT 1 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."shipment_progress_flow_stages" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."shipment_progress_flow_stages_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."shipment_progress_flow_stages_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."shipment_progress_flow_stages_id_seq" OWNED BY "public"."shipment_progress_flow_stages"."id";



CREATE SEQUENCE IF NOT EXISTS "public"."shipment_progress_flows_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."shipment_progress_flows_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."shipment_progress_flows_id_seq" OWNED BY "public"."shipment_progress_flows"."id";



CREATE SEQUENCE IF NOT EXISTS "public"."shipments_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."shipments_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."shipments_id_seq" OWNED BY "public"."shipments"."id";



ALTER TABLE "public"."stock_locations" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."stock_locations_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."stock_movement_lines" (
    "id" bigint NOT NULL,
    "movement_id" bigint NOT NULL,
    "stock_id" bigint,
    "from_location_id" bigint,
    "to_location_id" bigint,
    "from_availability" "public"."stock_availability",
    "to_availability" "public"."stock_availability",
    "quantity" numeric NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "from_grade_tag_id" bigint,
    "to_grade_tag_id" bigint,
    CONSTRAINT "stock_movement_lines_quantity_check" CHECK (("quantity" > (0)::numeric))
);


ALTER TABLE "public"."stock_movement_lines" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."stock_movement_lines_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."stock_movement_lines_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."stock_movement_lines_id_seq" OWNED BY "public"."stock_movement_lines"."id";



CREATE TABLE IF NOT EXISTS "public"."stock_movements" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "movement_no" "text" NOT NULL,
    "movement_type" "public"."stock_movement_type" NOT NULL,
    "reference_type" "text",
    "reference_id" "text",
    "notes" "text",
    "created_by_email" "text",
    "is_posted" boolean DEFAULT false NOT NULL,
    "posted_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."stock_movements" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."stock_movements_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."stock_movements_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."stock_movements_id_seq" OWNED BY "public"."stock_movements"."id";



CREATE SEQUENCE IF NOT EXISTS "public"."vendors_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."vendors_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."vendors_id_seq" OWNED BY "public"."vendors"."id";



ALTER TABLE ONLY "public"."costing_file_items" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."costing_file_items_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."costing_file_viewers" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."costing_file_viewers_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."costing_files" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."costing_files_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."global_shipment_boxes" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."global_shipment_boxes_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."global_shipment_items" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."global_shipment_items_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."global_shipment_sections" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."global_shipment_sections_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."global_shipments" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."global_shipments_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."global_stock_types" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."global_stock_types_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."global_stocks" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."global_stocks_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."product_based_costing_files" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."product_based_costing_files_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."product_based_costing_items" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."product_based_costing_items_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."shipment_investments" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."shipment_investments_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."shipment_items" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."shipment_items_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."shipment_progress_flow_stages" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."shipment_progress_flow_stages_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."shipment_progress_flows" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."shipment_progress_flows_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."shipments" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."shipments_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."stock_movement_lines" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."stock_movement_lines_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."stock_movements" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."stock_movements_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."vendors" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."vendors_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."costing_file_items"
    ADD CONSTRAINT "costing_file_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."costing_file_viewers"
    ADD CONSTRAINT "costing_file_viewers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."costing_file_viewers"
    ADD CONSTRAINT "costing_file_viewers_unique" UNIQUE ("costing_file_id", "membership_id");



ALTER TABLE ONLY "public"."costing_files"
    ADD CONSTRAINT "costing_files_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."global_shipment_boxes"
    ADD CONSTRAINT "global_shipment_boxes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."global_shipment_boxes"
    ADD CONSTRAINT "global_shipment_boxes_shipment_id_box_number_key" UNIQUE ("shipment_id", "box_number");



ALTER TABLE ONLY "public"."global_shipment_cost_entries"
    ADD CONSTRAINT "global_shipment_cost_entries_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."global_shipment_items"
    ADD CONSTRAINT "global_shipment_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."global_shipment_sections"
    ADD CONSTRAINT "global_shipment_sections_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."global_shipments"
    ADD CONSTRAINT "global_shipments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."global_stock_types"
    ADD CONSTRAINT "global_stock_types_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."global_stocks"
    ADD CONSTRAINT "global_stocks_grain_unique" UNIQUE ("shipment_item_id", "availability", "location_id", "grade_tag_id");



ALTER TABLE ONLY "public"."global_stocks"
    ADD CONSTRAINT "global_stocks_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."product_based_costing_backlog_items"
    ADD CONSTRAINT "product_based_costing_backlog_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."product_based_costing_files"
    ADD CONSTRAINT "product_based_costing_files_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."product_based_costing_items"
    ADD CONSTRAINT "product_based_costing_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."shipment_investments"
    ADD CONSTRAINT "shipment_investments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."shipment_items"
    ADD CONSTRAINT "shipment_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."shipment_progress_flow_stages"
    ADD CONSTRAINT "shipment_progress_flow_stages_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."shipment_progress_flows"
    ADD CONSTRAINT "shipment_progress_flows_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."shipments"
    ADD CONSTRAINT "shipments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."stock_locations"
    ADD CONSTRAINT "stock_locations_parent_code_unique" UNIQUE ("parent_tenant_id", "code");



ALTER TABLE ONLY "public"."stock_locations"
    ADD CONSTRAINT "stock_locations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."stock_movement_lines"
    ADD CONSTRAINT "stock_movement_lines_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."stock_movements"
    ADD CONSTRAINT "stock_movements_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."product_based_costing_backlog_items"
    ADD CONSTRAINT "uq_pbc_backlog_tenant_profile_product" UNIQUE ("tenant_id", "billing_profile_id", "product_id");



ALTER TABLE ONLY "public"."vendors"
    ADD CONSTRAINT "vendors_pkey" PRIMARY KEY ("id");



CREATE INDEX "costing_file_items_costing_file_id_idx" ON "public"."costing_file_items" USING "btree" ("costing_file_id");



CREATE INDEX "costing_file_items_status_idx" ON "public"."costing_file_items" USING "btree" ("status");



CREATE INDEX "costing_file_viewers_costing_file_id_idx" ON "public"."costing_file_viewers" USING "btree" ("costing_file_id");



CREATE INDEX "costing_file_viewers_membership_id_idx" ON "public"."costing_file_viewers" USING "btree" ("membership_id");



CREATE INDEX "costing_files_customer_group_id_idx" ON "public"."costing_files" USING "btree" ("customer_group_id");



CREATE INDEX "costing_files_status_idx" ON "public"."costing_files" USING "btree" ("status");



CREATE INDEX "costing_files_tenant_id_idx" ON "public"."costing_files" USING "btree" ("tenant_id");



CREATE INDEX "global_shipment_boxes_parent_tenant_idx" ON "public"."global_shipment_boxes" USING "btree" ("parent_tenant_id");



CREATE INDEX "global_shipment_boxes_shipment_idx" ON "public"."global_shipment_boxes" USING "btree" ("shipment_id");



CREATE INDEX "global_shipment_cost_entries_parent_tenant_idx" ON "public"."global_shipment_cost_entries" USING "btree" ("parent_tenant_id");



CREATE INDEX "global_shipment_cost_entries_settled_idx" ON "public"."global_shipment_cost_entries" USING "btree" ("shipment_id") WHERE ("settled_at" IS NULL);



CREATE INDEX "global_shipment_cost_entries_shipment_idx" ON "public"."global_shipment_cost_entries" USING "btree" ("shipment_id");



CREATE INDEX "global_shipment_cost_entries_type_idx" ON "public"."global_shipment_cost_entries" USING "btree" ("shipment_id", "cost_type");



CREATE INDEX "global_shipment_items_product_idx" ON "public"."global_shipment_items" USING "btree" ("product_id");



CREATE INDEX "global_shipment_items_shipment_idx" ON "public"."global_shipment_items" USING "btree" ("shipment_id");



CREATE INDEX "global_shipments_assigned_child_idx" ON "public"."global_shipments" USING "btree" ("assigned_child_tenant_id") WHERE ("assigned_child_tenant_id" IS NOT NULL);



CREATE INDEX "global_shipments_cargo_company_idx" ON "public"."global_shipments" USING "btree" ("cargo_company_id");



CREATE INDEX "global_shipments_parent_tenant_idx" ON "public"."global_shipments" USING "btree" ("parent_tenant_id");



CREATE INDEX "global_shipments_progress_flow_idx" ON "public"."global_shipments" USING "btree" ("progress_flow_id");



CREATE INDEX "global_shipments_progress_tag_id_idx" ON "public"."global_shipments" USING "btree" ("progress_tag_id");



CREATE UNIQUE INDEX "global_shipments_public_tracking_token_key" ON "public"."global_shipments" USING "btree" ("public_tracking_token") WHERE ("public_tracking_token" IS NOT NULL);



CREATE INDEX "global_shipments_vendor_idx" ON "public"."global_shipments" USING "btree" ("vendor_id");



CREATE INDEX "global_stock_types_parent_tenant_idx" ON "public"."global_stock_types" USING "btree" ("parent_tenant_id");



CREATE INDEX "global_stocks_availability_idx" ON "public"."global_stocks" USING "btree" ("availability");



CREATE INDEX "global_stocks_location_id_idx" ON "public"."global_stocks" USING "btree" ("location_id");



CREATE INDEX "global_stocks_parent_tenant_idx" ON "public"."global_stocks" USING "btree" ("parent_tenant_id");



CREATE INDEX "global_stocks_shipment_item_idx" ON "public"."global_stocks" USING "btree" ("shipment_item_id");



CREATE INDEX "global_stocks_stock_type_idx" ON "public"."global_stocks" USING "btree" ("stock_type_id");



CREATE INDEX "idx_pbc_backlog_tenant_profile" ON "public"."product_based_costing_backlog_items" USING "btree" ("tenant_id", "billing_profile_id");



CREATE INDEX "product_based_costing_files_billing_profile_id_idx" ON "public"."product_based_costing_files" USING "btree" ("billing_profile_id");



CREATE INDEX "product_based_costing_files_default_shipment_id_idx" ON "public"."product_based_costing_files" USING "btree" ("default_shipment_id");



CREATE INDEX "product_based_costing_files_invoice_id_idx" ON "public"."product_based_costing_files" USING "btree" ("invoice_id");



CREATE INDEX "product_based_costing_files_market_code_idx" ON "public"."product_based_costing_files" USING "btree" ("market_code");



CREATE INDEX "product_based_costing_files_name_idx" ON "public"."product_based_costing_files" USING "btree" ("name");



CREATE INDEX "product_based_costing_files_status_idx" ON "public"."product_based_costing_files" USING "btree" ("status");



CREATE INDEX "product_based_costing_files_tenant_id_idx" ON "public"."product_based_costing_files" USING "btree" ("tenant_id");



CREATE INDEX "product_based_costing_files_vendor_code_idx" ON "public"."product_based_costing_files" USING "btree" ("vendor_code");



CREATE INDEX "product_based_costing_files_vendor_id_idx" ON "public"."product_based_costing_files" USING "btree" ("vendor_id");



CREATE INDEX "product_based_costing_items_assigned_shipment_id_idx" ON "public"."product_based_costing_items" USING "btree" ("assigned_shipment_id");



CREATE INDEX "product_based_costing_items_barcode_idx" ON "public"."product_based_costing_items" USING "btree" ("barcode");



CREATE INDEX "product_based_costing_items_brand_idx" ON "public"."product_based_costing_items" USING "btree" ("brand");



CREATE INDEX "product_based_costing_items_file_id_idx" ON "public"."product_based_costing_items" USING "btree" ("product_based_costing_file_id");



CREATE INDEX "product_based_costing_items_market_code_idx" ON "public"."product_based_costing_items" USING "btree" ("market_code");



CREATE INDEX "product_based_costing_items_name_idx" ON "public"."product_based_costing_items" USING "btree" ("name");



CREATE INDEX "product_based_costing_items_note_idx" ON "public"."product_based_costing_items" USING "gin" ("to_tsvector"('"simple"'::"regconfig", COALESCE("note", ''::"text")));



CREATE INDEX "product_based_costing_items_product_code_idx" ON "public"."product_based_costing_items" USING "btree" ("product_code");



CREATE INDEX "product_based_costing_items_vendor_code_idx" ON "public"."product_based_costing_items" USING "btree" ("vendor_code");



CREATE INDEX "product_based_costing_items_vendor_id_idx" ON "public"."product_based_costing_items" USING "btree" ("vendor_id");



CREATE INDEX "shipment_investments_global_shipment_id_idx" ON "public"."shipment_investments" USING "btree" ("global_shipment_id");



CREATE INDEX "shipment_investments_investor_id_idx" ON "public"."shipment_investments" USING "btree" ("investor_id");



CREATE INDEX "shipment_investments_shipment_id_idx" ON "public"."shipment_investments" USING "btree" ("shipment_id");



CREATE INDEX "shipment_investments_tenant_id_idx" ON "public"."shipment_investments" USING "btree" ("tenant_id");



CREATE INDEX "shipment_items_marker_tag_idx" ON "public"."shipment_items" USING "btree" ("marker_tag");



CREATE INDEX "shipment_items_method_idx" ON "public"."shipment_items" USING "btree" ("method");



CREATE INDEX "shipment_items_order_id_idx" ON "public"."shipment_items" USING "btree" ("order_id");



CREATE INDEX "shipment_items_product_id_idx" ON "public"."shipment_items" USING "btree" ("product_id");



CREATE INDEX "shipment_items_shipment_id_idx" ON "public"."shipment_items" USING "btree" ("shipment_id");



CREATE UNIQUE INDEX "shipment_items_shipment_product_unique" ON "public"."shipment_items" USING "btree" ("shipment_id", "product_id") WHERE ("product_id" IS NOT NULL);



CREATE INDEX "shipment_items_source_idx" ON "public"."shipment_items" USING "btree" ("source_type", "source_id");



CREATE UNIQUE INDEX "shipment_progress_flow_stages_flow_sort_key" ON "public"."shipment_progress_flow_stages" USING "btree" ("flow_id", "sort_order");



CREATE UNIQUE INDEX "shipment_progress_flow_stages_flow_tag_key" ON "public"."shipment_progress_flow_stages" USING "btree" ("flow_id", "tag_id");



CREATE UNIQUE INDEX "shipment_progress_flows_one_default_per_tenant" ON "public"."shipment_progress_flows" USING "btree" ("tenant_id") WHERE ("is_default" = true);



CREATE UNIQUE INDEX "shipment_progress_flows_tenant_slug_key" ON "public"."shipment_progress_flows" USING "btree" ("tenant_id", "slug");



CREATE INDEX "shipments_market_code_idx" ON "public"."shipments" USING "btree" ("market_code");



CREATE INDEX "shipments_status_idx" ON "public"."shipments" USING "btree" ("status");



CREATE INDEX "shipments_tenant_id_idx" ON "public"."shipments" USING "btree" ("tenant_id");



CREATE UNIQUE INDEX "shipments_tenant_id_tenant_shipment_id_uidx" ON "public"."shipments" USING "btree" ("tenant_id", "tenant_shipment_id");



CREATE INDEX "shipments_tenant_shipment_id_idx" ON "public"."shipments" USING "btree" ("tenant_shipment_id");



CREATE UNIQUE INDEX "stock_locations_one_default_per_parent_idx" ON "public"."stock_locations" USING "btree" ("parent_tenant_id") WHERE (("is_default" = true) AND ("is_active" = true));



CREATE INDEX "stock_locations_parent_active_idx" ON "public"."stock_locations" USING "btree" ("parent_tenant_id", "is_active");



CREATE INDEX "stock_locations_parent_location_idx" ON "public"."stock_locations" USING "btree" ("parent_location_id");



CREATE INDEX "stock_locations_parent_sort_idx" ON "public"."stock_locations" USING "btree" ("parent_tenant_id", "sort_order");



CREATE UNIQUE INDEX "vendors_global_code_unique_idx" ON "public"."vendors" USING "btree" ("upper"(TRIM(BOTH FROM "code"))) WHERE ("tenant_id" IS NULL);



CREATE INDEX "vendors_market_code_idx" ON "public"."vendors" USING "btree" ("market_code");



CREATE UNIQUE INDEX "vendors_one_default_per_tenant_idx" ON "public"."vendors" USING "btree" ("tenant_id") WHERE (("is_default" = true) AND ("tenant_id" IS NOT NULL));



CREATE INDEX "vendors_parent_tenant_id_idx" ON "public"."vendors" USING "btree" ("parent_tenant_id");



CREATE UNIQUE INDEX "vendors_tenant_code_unique_idx" ON "public"."vendors" USING "btree" ("tenant_id", "upper"(TRIM(BOTH FROM "code"))) WHERE ("tenant_id" IS NOT NULL);



CREATE INDEX "vendors_tenant_id_idx" ON "public"."vendors" USING "btree" ("tenant_id");



ALTER TABLE ONLY "public"."batch_code_pc"
    ADD CONSTRAINT "batch_code_pc_shipment_id_fkey" FOREIGN KEY ("shipment_id") REFERENCES "public"."shipments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."batch_code_pc"
    ADD CONSTRAINT "batch_code_pc_shipment_item_id_fkey" FOREIGN KEY ("shipment_item_id") REFERENCES "public"."shipment_items"("id") ON DELETE CASCADE;






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



ALTER TABLE ONLY "public"."product_based_costing_items"
    ADD CONSTRAINT "fk_product_based_costing_items_product" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."sales_invoice_items"
    ADD CONSTRAINT "global_invoice_items_global_stock_id_fkey" FOREIGN KEY ("global_stock_id") REFERENCES "public"."global_stocks"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."sales_invoice_items"
    ADD CONSTRAINT "global_invoice_items_shipment_item_id_fkey" FOREIGN KEY ("shipment_item_id") REFERENCES "public"."global_shipment_items"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."sales_return_items"
    ADD CONSTRAINT "global_return_items_global_stock_id_fkey" FOREIGN KEY ("global_stock_id") REFERENCES "public"."global_stocks"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."global_shipment_boxes"
    ADD CONSTRAINT "global_shipment_boxes_parent_tenant_id_fkey" FOREIGN KEY ("parent_tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."global_shipment_boxes"
    ADD CONSTRAINT "global_shipment_boxes_shipment_id_fkey" FOREIGN KEY ("shipment_id") REFERENCES "public"."global_shipments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."global_shipment_cost_entries"
    ADD CONSTRAINT "global_shipment_cost_entries_currency_id_fkey" FOREIGN KEY ("currency_id") REFERENCES "public"."global_currencies"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."global_shipment_cost_entries"
    ADD CONSTRAINT "global_shipment_cost_entries_parent_tenant_id_fkey" FOREIGN KEY ("parent_tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."global_shipment_cost_entries"
    ADD CONSTRAINT "global_shipment_cost_entries_shipment_id_fkey" FOREIGN KEY ("shipment_id") REFERENCES "public"."global_shipments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."global_shipment_cost_entries"
    ADD CONSTRAINT "global_shipment_cost_entries_section_id_fkey" FOREIGN KEY ("section_id") REFERENCES "public"."global_shipment_sections"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."global_shipment_items"
    ADD CONSTRAINT "global_shipment_items_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."global_shipment_items"
    ADD CONSTRAINT "global_shipment_items_shipment_id_fkey" FOREIGN KEY ("shipment_id") REFERENCES "public"."global_shipments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."global_shipment_items"
    ADD CONSTRAINT "global_shipment_items_section_id_fkey" FOREIGN KEY ("section_id") REFERENCES "public"."global_shipment_sections"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."global_shipment_sections"
    ADD CONSTRAINT "global_shipment_sections_parent_tenant_id_fkey" FOREIGN KEY ("parent_tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."global_shipment_sections"
    ADD CONSTRAINT "global_shipment_sections_shipment_id_fkey" FOREIGN KEY ("shipment_id") REFERENCES "public"."global_shipments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."global_shipment_sections"
    ADD CONSTRAINT "global_shipment_sections_vendor_id_fkey" FOREIGN KEY ("vendor_id") REFERENCES "public"."vendors"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."global_shipment_items"
    ADD CONSTRAINT "global_shipment_items_source_child_tenant_id_fkey" FOREIGN KEY ("source_child_tenant_id") REFERENCES "public"."tenants"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."global_shipment_items"
    ADD CONSTRAINT "global_shipment_items_vendor_id_fkey" FOREIGN KEY ("vendor_id") REFERENCES "public"."vendors"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."global_shipments"
    ADD CONSTRAINT "global_shipments_assigned_child_tenant_id_fkey" FOREIGN KEY ("assigned_child_tenant_id") REFERENCES "public"."tenants"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."global_shipments"
    ADD CONSTRAINT "global_shipments_cargo_company_id_fkey" FOREIGN KEY ("cargo_company_id") REFERENCES "public"."cargo_companies"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."global_shipments"
    ADD CONSTRAINT "global_shipments_parent_tenant_id_fkey" FOREIGN KEY ("parent_tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."global_shipments"
    ADD CONSTRAINT "global_shipments_progress_flow_id_fkey" FOREIGN KEY ("progress_flow_id") REFERENCES "public"."shipment_progress_flows"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."global_shipments"
    ADD CONSTRAINT "global_shipments_progress_tag_id_fkey" FOREIGN KEY ("progress_tag_id") REFERENCES "public"."tags"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."global_shipments"
    ADD CONSTRAINT "global_shipments_shipment_cost_currency_id_fkey" FOREIGN KEY ("shipment_cost_currency_id") REFERENCES "public"."global_currencies"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."global_shipments"
    ADD CONSTRAINT "global_shipments_shipment_purchase_currency_id_fkey" FOREIGN KEY ("shipment_purchase_currency_id") REFERENCES "public"."global_currencies"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."global_shipments"
    ADD CONSTRAINT "global_shipments_vendor_id_fkey" FOREIGN KEY ("vendor_id") REFERENCES "public"."vendors"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."global_stock_types"
    ADD CONSTRAINT "global_stock_types_parent_tenant_id_fkey" FOREIGN KEY ("parent_tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."global_stocks"
    ADD CONSTRAINT "global_stocks_grade_tag_id_fkey" FOREIGN KEY ("grade_tag_id") REFERENCES "public"."tags"("id");



ALTER TABLE ONLY "public"."global_stocks"
    ADD CONSTRAINT "global_stocks_location_id_fkey" FOREIGN KEY ("location_id") REFERENCES "public"."stock_locations"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."global_stocks"
    ADD CONSTRAINT "global_stocks_parent_tenant_id_fkey" FOREIGN KEY ("parent_tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."global_stocks"
    ADD CONSTRAINT "global_stocks_shipment_item_id_fkey" FOREIGN KEY ("shipment_item_id") REFERENCES "public"."global_shipment_items"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."global_stocks"
    ADD CONSTRAINT "global_stocks_stock_type_id_fkey" FOREIGN KEY ("stock_type_id") REFERENCES "public"."global_stock_types"("id") ON DELETE CASCADE;






ALTER TABLE ONLY "public"."product_based_costing_backlog_items"
    ADD CONSTRAINT "product_based_costing_backlog_items_billing_profile_id_fkey" FOREIGN KEY ("billing_profile_id") REFERENCES "public"."billing_profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."product_based_costing_backlog_items"
    ADD CONSTRAINT "product_based_costing_backlog_items_last_costing_file_id_fkey" FOREIGN KEY ("last_costing_file_id") REFERENCES "public"."product_based_costing_files"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."product_based_costing_backlog_items"
    ADD CONSTRAINT "product_based_costing_backlog_items_last_costing_item_id_fkey" FOREIGN KEY ("last_costing_item_id") REFERENCES "public"."product_based_costing_items"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."product_based_costing_backlog_items"
    ADD CONSTRAINT "product_based_costing_backlog_items_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."product_based_costing_backlog_items"
    ADD CONSTRAINT "product_based_costing_backlog_items_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."product_based_costing_files"
    ADD CONSTRAINT "product_based_costing_files_billing_profile_id_fkey" FOREIGN KEY ("billing_profile_id") REFERENCES "public"."billing_profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."product_based_costing_files"
    ADD CONSTRAINT "product_based_costing_files_default_shipment_id_fkey" FOREIGN KEY ("default_shipment_id") REFERENCES "public"."global_shipments"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."product_based_costing_files"
    ADD CONSTRAINT "product_based_costing_files_market_code_fkey" FOREIGN KEY ("market_code") REFERENCES "public"."markets"("code") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."product_based_costing_files"
    ADD CONSTRAINT "product_based_costing_files_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."product_based_costing_files"
    ADD CONSTRAINT "product_based_costing_files_vendor_id_fkey" FOREIGN KEY ("vendor_id") REFERENCES "public"."vendors"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."product_based_costing_items"
    ADD CONSTRAINT "product_based_costing_items_assigned_shipment_id_fkey" FOREIGN KEY ("assigned_shipment_id") REFERENCES "public"."global_shipments"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."product_based_costing_items"
    ADD CONSTRAINT "product_based_costing_items_product_based_costing_file_id_fkey" FOREIGN KEY ("product_based_costing_file_id") REFERENCES "public"."product_based_costing_files"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."product_based_costing_items"
    ADD CONSTRAINT "product_based_costing_items_vendor_id_fkey" FOREIGN KEY ("vendor_id") REFERENCES "public"."vendors"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."product_brands"
    ADD CONSTRAINT "product_brands_vendor_id_fkey" FOREIGN KEY ("vendor_id") REFERENCES "public"."vendors"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."product_categories"
    ADD CONSTRAINT "product_categories_vendor_id_fkey" FOREIGN KEY ("vendor_id") REFERENCES "public"."vendors"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."product_sync_snapshots"
    ADD CONSTRAINT "product_sync_snapshots_vendor_id_fkey" FOREIGN KEY ("vendor_id") REFERENCES "public"."vendors"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_vendor_id_fkey" FOREIGN KEY ("vendor_id") REFERENCES "public"."vendors"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."shipment_investments"
    ADD CONSTRAINT "shipment_investments_global_shipment_id_fkey" FOREIGN KEY ("global_shipment_id") REFERENCES "public"."global_shipments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."shipment_investments"
    ADD CONSTRAINT "shipment_investments_investor_id_fkey" FOREIGN KEY ("investor_id") REFERENCES "public"."investors"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."shipment_investments"
    ADD CONSTRAINT "shipment_investments_shipment_id_fkey" FOREIGN KEY ("shipment_id") REFERENCES "public"."shipments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."shipment_investments"
    ADD CONSTRAINT "shipment_investments_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;






ALTER TABLE ONLY "public"."shipment_items"
    ADD CONSTRAINT "shipment_items_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."shipment_items"
    ADD CONSTRAINT "shipment_items_shipment_id_fkey" FOREIGN KEY ("shipment_id") REFERENCES "public"."shipments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."shipment_items"
    ADD CONSTRAINT "shipment_items_source_child_tenant_id_fkey" FOREIGN KEY ("source_child_tenant_id") REFERENCES "public"."tenants"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."shipment_progress_flow_stages"
    ADD CONSTRAINT "shipment_progress_flow_stages_flow_id_fkey" FOREIGN KEY ("flow_id") REFERENCES "public"."shipment_progress_flows"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."shipment_progress_flow_stages"
    ADD CONSTRAINT "shipment_progress_flow_stages_tag_id_fkey" FOREIGN KEY ("tag_id") REFERENCES "public"."tags"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."shipment_progress_flows"
    ADD CONSTRAINT "shipment_progress_flows_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."shipments"
    ADD CONSTRAINT "shipments_market_code_fkey" FOREIGN KEY ("market_code") REFERENCES "public"."markets"("code") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."shipments"
    ADD CONSTRAINT "shipments_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."shop_cart_items"
    ADD CONSTRAINT "shop_cart_items_global_stock_id_fkey" FOREIGN KEY ("global_stock_id") REFERENCES "public"."global_stocks"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."shop_order_items"
    ADD CONSTRAINT "shop_order_items_global_stock_id_fkey" FOREIGN KEY ("global_stock_id") REFERENCES "public"."global_stocks"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."shop_product_listings"
    ADD CONSTRAINT "shop_product_listings_global_stock_id_fkey" FOREIGN KEY ("global_stock_id") REFERENCES "public"."global_stocks"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."shop_stock_reservations"
    ADD CONSTRAINT "shop_stock_reservations_global_stock_id_fkey" FOREIGN KEY ("global_stock_id") REFERENCES "public"."global_stocks"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."stock_locations"
    ADD CONSTRAINT "stock_locations_parent_location_id_fkey" FOREIGN KEY ("parent_location_id") REFERENCES "public"."stock_locations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."stock_locations"
    ADD CONSTRAINT "stock_locations_parent_tenant_id_fkey" FOREIGN KEY ("parent_tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."stock_movement_lines"
    ADD CONSTRAINT "stock_movement_lines_from_grade_tag_id_fkey" FOREIGN KEY ("from_grade_tag_id") REFERENCES "public"."tags"("id");



ALTER TABLE ONLY "public"."stock_movement_lines"
    ADD CONSTRAINT "stock_movement_lines_from_location_id_fkey" FOREIGN KEY ("from_location_id") REFERENCES "public"."stock_locations"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."stock_movement_lines"
    ADD CONSTRAINT "stock_movement_lines_movement_id_fkey" FOREIGN KEY ("movement_id") REFERENCES "public"."stock_movements"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."stock_movement_lines"
    ADD CONSTRAINT "stock_movement_lines_stock_id_fkey" FOREIGN KEY ("stock_id") REFERENCES "public"."global_stocks"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."stock_movement_lines"
    ADD CONSTRAINT "stock_movement_lines_to_grade_tag_id_fkey" FOREIGN KEY ("to_grade_tag_id") REFERENCES "public"."tags"("id");



ALTER TABLE ONLY "public"."stock_movement_lines"
    ADD CONSTRAINT "stock_movement_lines_to_location_id_fkey" FOREIGN KEY ("to_location_id") REFERENCES "public"."stock_locations"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."stock_movements"
    ADD CONSTRAINT "stock_movements_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;






ALTER TABLE ONLY "public"."vendors"
    ADD CONSTRAINT "vendors_market_code_fkey" FOREIGN KEY ("market_code") REFERENCES "public"."markets"("code");



ALTER TABLE ONLY "public"."vendors"
    ADD CONSTRAINT "vendors_parent_tenant_id_fkey" FOREIGN KEY ("parent_tenant_id") REFERENCES "public"."tenants"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."vendors"
    ADD CONSTRAINT "vendors_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



