-- Extracted from supabase/schemas/public.sql (shop_order). Move-only.

CREATE TABLE IF NOT EXISTS "public"."customer_group_shop_profiles" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "customer_group_id" bigint NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "default_can_browse" boolean DEFAULT true NOT NULL,
    "default_can_see_buy_price" boolean DEFAULT false NOT NULL,
    "default_can_see_sell_price" boolean DEFAULT false NOT NULL,
    "default_can_see_resell_minimum_price" boolean DEFAULT true NOT NULL,
    "default_can_add_to_cart" boolean DEFAULT true NOT NULL,
    "default_can_place_order" boolean DEFAULT true NOT NULL,
    "default_can_negotiate" boolean DEFAULT false NOT NULL,
    "default_can_view_quantity" boolean DEFAULT true NOT NULL,
    "default_can_set_dropship_price" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."customer_group_shop_profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."shops" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "name" "text" NOT NULL,
    "slug" "text" NOT NULL,
    "shop_type" "public"."shop_type_enum" NOT NULL,
    "vendor_code" "text",
    "order_mode" "public"."shop_order_mode_enum" NOT NULL,
    "is_negotiable" boolean DEFAULT false NOT NULL,
    "show_stock_quantity" boolean DEFAULT true NOT NULL,
    "default_currency_id" bigint,
    "global_stock_type_id" bigint,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "allow_delivery" boolean DEFAULT false NOT NULL,
    "buy_currency_id" bigint NOT NULL,
    "sell_currency_id" bigint NOT NULL,
    "pricing_method" "text" NOT NULL,
    "markup_percentage" numeric(5,2) DEFAULT 0 NOT NULL,
    "quantity_display_mode" "text" NOT NULL,
    "default_print_charge_amount" numeric(12,2) DEFAULT 0 NOT NULL,
    "default_packing_charge_amount" numeric(12,2) DEFAULT 0 NOT NULL,
    "deduct_charges_from_margin" boolean DEFAULT false NOT NULL,
    "vendor_filters" "jsonb",
    "deduct_print_from_margin" boolean DEFAULT false NOT NULL,
    "deduct_packing_from_margin" boolean DEFAULT false NOT NULL,
    "deduct_return_charge_from_middle_man" boolean DEFAULT true,
    "description" "text",
    "category_ids" bigint[] DEFAULT '{}'::bigint[],
    "deleted_at" timestamp with time zone,
    "deleted_by" "text",
    CONSTRAINT "shops_dropship_not_negotiable" CHECK ((("shop_type" <> 'dropship'::"public"."shop_type_enum") OR ("is_negotiable" = false))),
    CONSTRAINT "shops_markup_percentage_check" CHECK (("markup_percentage" >= (0)::numeric)),
    CONSTRAINT "shops_pricing_method_check" CHECK (("pricing_method" = ANY (ARRAY['direct_cost'::"text", 'markup'::"text"]))),
    CONSTRAINT "shops_quantity_display_mode_check" CHECK (("quantity_display_mode" = ANY (ARRAY['original'::"text", 'custom_override'::"text"]))),
    CONSTRAINT "shops_sell_currency_match" CHECK (("sell_currency_id" = "default_currency_id")),
    CONSTRAINT "shops_vendor_catalog_requires_vendor_code" CHECK ((("shop_type" <> 'vendor_catalog'::"public"."shop_type_enum") OR ("is_active" = false) OR ("vendor_code" IS NOT NULL) OR (("vendor_filters" IS NOT NULL) AND ("jsonb_array_length"("vendor_filters") > 0))))
);


ALTER TABLE "public"."shops" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."shop_customer_group_access" (
    "id" bigint NOT NULL,
    "shop_id" bigint NOT NULL,
    "customer_group_id" bigint NOT NULL,
    "status" boolean DEFAULT true NOT NULL,
    "can_browse" boolean,
    "can_see_buy_price" boolean,
    "can_see_sell_price" boolean,
    "can_see_resell_minimum_price" boolean,
    "can_add_to_cart" boolean,
    "can_place_order" boolean,
    "can_negotiate" boolean,
    "can_view_quantity" boolean,
    "can_set_dropship_price" boolean,
    "price_tier_code" "text",
    "credit_limit_amount" numeric(12,4) DEFAULT NULL::numeric,
    "credit_limit_currency_id" bigint,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "shop_customer_group_access_credit_limit_currency" CHECK ((("credit_limit_amount" IS NULL) = ("credit_limit_currency_id" IS NULL)))
);


ALTER TABLE "public"."shop_customer_group_access" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."shop_pricing_rules" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "shop_id" bigint NOT NULL,
    "markup_percentage" numeric(8,2) DEFAULT 0.00 NOT NULL,
    "is_auto_publish" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "default_show_quantity" boolean DEFAULT true NOT NULL,
    "default_add_quantity" integer DEFAULT 0 NOT NULL,
    "dropship_markup_percentage" numeric(8,2) DEFAULT 0.00 NOT NULL,
    CONSTRAINT "shop_pricing_rules_dropship_markup_non_negative" CHECK (("dropship_markup_percentage" >= (0)::numeric)),
    CONSTRAINT "shop_pricing_rules_markup_non_negative" CHECK (("markup_percentage" >= (0)::numeric))
);


ALTER TABLE "public"."shop_pricing_rules" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."shop_product_listings" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "shop_id" bigint NOT NULL,
    "global_stock_allocation_id" bigint,
    "global_stock_id" bigint NOT NULL,
    "product_id" bigint NOT NULL,
    "sell_price_amount" numeric(12,4) NOT NULL,
    "sell_price_currency_id" bigint NOT NULL,
    "minimum_sell_price_amount" numeric(12,4) DEFAULT NULL::numeric,
    "minimum_sell_price_currency_id" bigint,
    "show_quantity" boolean,
    "display_quantity_override" integer,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "is_price_locked" boolean DEFAULT false NOT NULL,
    "is_quantity_locked" boolean DEFAULT false NOT NULL,
    "quantity_override_type" "text" DEFAULT 'absolute'::"text" NOT NULL,
    CONSTRAINT "shop_product_listings_min_sell_currency" CHECK ((("minimum_sell_price_amount" IS NULL) = ("minimum_sell_price_currency_id" IS NULL))),
    CONSTRAINT "shop_product_listings_qty_override_type_check" CHECK (("quantity_override_type" = ANY (ARRAY['absolute'::"text", 'relative'::"text"])))
);


ALTER TABLE "public"."shop_product_listings" OWNER TO "postgres";


ALTER TABLE "public"."customer_group_shop_profiles" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."customer_group_shop_profiles_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


CREATE TABLE IF NOT EXISTS "public"."shop_cart_items" (
    "id" bigint NOT NULL,
    "cart_id" bigint NOT NULL,
    "product_id" bigint NOT NULL,
    "global_stock_id" bigint,
    "global_stock_allocation_id" bigint,
    "quantity" integer NOT NULL,
    "minimum_quantity" integer DEFAULT 1 NOT NULL,
    "unit_list_price_amount" numeric(12,4),
    "unit_list_price_currency_id" bigint,
    "unit_sell_price_amount" numeric(12,4),
    "unit_sell_price_currency_id" bigint,
    "unit_minimum_sell_price_amount" numeric(12,4),
    "unit_minimum_sell_price_currency_id" bigint,
    "customer_sell_price_amount" numeric(12,4),
    "customer_sell_price_currency_id" bigint,
    "name" "text" NOT NULL,
    "image_url" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "shop_cart_items_min_qty_positive" CHECK (("minimum_quantity" > 0)),
    CONSTRAINT "shop_cart_items_qty_positive" CHECK (("quantity" > 0))
);


ALTER TABLE "public"."shop_cart_items" OWNER TO "postgres";


ALTER TABLE "public"."shop_cart_items" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."shop_cart_items_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


CREATE TABLE IF NOT EXISTS "public"."shop_carts" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "shop_id" bigint NOT NULL,
    "customer_group_id" bigint NOT NULL,
    "can_see_buy_price_snapshot" boolean DEFAULT false NOT NULL,
    "can_see_sell_price_snapshot" boolean DEFAULT false NOT NULL,
    "status" "public"."shop_cart_status" DEFAULT 'active'::"public"."shop_cart_status" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "cod_charge_amount" numeric(12,2) DEFAULT 0 NOT NULL,
    "delivery_charge_amount" numeric(12,2) DEFAULT 0 NOT NULL,
    "print_charge_amount" numeric(12,2) DEFAULT 0 NOT NULL,
    "packing_charge_amount" numeric(12,2) DEFAULT 0 NOT NULL,
    "discount_amount" numeric(12,2) DEFAULT 0 NOT NULL,
    "is_prepaid" boolean DEFAULT false NOT NULL,
    "delivery_instructions" "text",
    "deduct_charges_from_margin" boolean DEFAULT false NOT NULL,
    "deduct_print_from_margin" boolean DEFAULT false NOT NULL,
    "deduct_packing_from_margin" boolean DEFAULT false NOT NULL
);


ALTER TABLE "public"."shop_carts" OWNER TO "postgres";


ALTER TABLE "public"."shop_carts" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."shop_carts_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


CREATE TABLE IF NOT EXISTS "public"."shop_categories" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "name" character varying(255) NOT NULL,
    "slug" character varying(255) NOT NULL,
    "description" "text",
    "icon" character varying(100) DEFAULT 'category'::character varying,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."shop_categories" OWNER TO "postgres";


ALTER TABLE "public"."shop_categories" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."shop_categories_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


ALTER TABLE "public"."shop_customer_group_access" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."shop_customer_group_access_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


CREATE TABLE IF NOT EXISTS "public"."shop_order_items" (
    "id" bigint NOT NULL,
    "order_id" bigint NOT NULL,
    "product_id" bigint NOT NULL,
    "global_stock_id" bigint,
    "global_stock_allocation_id" bigint,
    "name" "text" NOT NULL,
    "image_url" "text",
    "quantity" integer NOT NULL,
    "unit_list_price_amount" numeric(12,4),
    "unit_list_price_currency_id" bigint,
    "unit_sell_price_amount" numeric(12,4),
    "unit_sell_price_currency_id" bigint,
    "unit_minimum_sell_price_amount" numeric(12,4),
    "unit_minimum_sell_price_currency_id" bigint,
    "customer_sell_price_amount" numeric(12,4),
    "customer_sell_price_currency_id" bigint,
    "customer_offer_amount" numeric(12,4),
    "customer_offer_currency_id" bigint,
    "staff_offer_amount" numeric(12,4),
    "staff_offer_currency_id" bigint,
    "final_price_amount" numeric(12,4),
    "final_price_currency_id" bigint,
    "returned_quantity" integer DEFAULT 0 NOT NULL,
    "procurement_pulled" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "is_first_offer_manual" boolean DEFAULT false NOT NULL,
    "is_final_offer_manual" boolean DEFAULT false NOT NULL,
    "confirmed_quantity" integer,
    "weight_kg" numeric(12,4),
    "cost_price_amount" numeric(12,4),
    "cost_price_currency_id" bigint,
    "customer_decision_status" "text" DEFAULT 'pending'::"text",
    "customer_decision_at" timestamp with time zone,
    "negotiation_status" "text" DEFAULT 'pending'::"text",
    "staff_offer_at" timestamp with time zone,
    "customer_counter_at" timestamp with time zone,
    "final_offer_at" timestamp with time zone,
    CONSTRAINT "shop_order_items_qty_non_negative" CHECK (("quantity" >= 0))
);


ALTER TABLE "public"."shop_order_items" OWNER TO "postgres";


ALTER TABLE "public"."shop_order_items" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."shop_order_items_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


CREATE TABLE IF NOT EXISTS "public"."shop_orders" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "shop_id" bigint NOT NULL,
    "customer_group_id" bigint NOT NULL,
    "cart_id" bigint,
    "order_no" "text" NOT NULL,
    "name" "text" NOT NULL,
    "shop_type_snapshot" "public"."shop_type_enum" NOT NULL,
    "order_mode_snapshot" "public"."shop_order_mode_enum" NOT NULL,
    "is_negotiable_snapshot" boolean DEFAULT false NOT NULL,
    "status" "public"."shop_order_status" DEFAULT 'submitted'::"public"."shop_order_status" NOT NULL,
    "negotiate_round" integer DEFAULT 0 NOT NULL,
    "cargo_rate" numeric(12,4),
    "conversion_rate" numeric(12,4),
    "profit_rate" numeric(12,4),
    "recipient_name" "text",
    "recipient_phone" "text",
    "shipping_address" "text",
    "billing_profile_id" bigint,
    "placed_at" timestamp with time zone,
    "fulfilled_at" timestamp with time zone,
    "global_invoice_id" bigint,
    "created_by_email" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "cod_charge_amount" numeric(12,2) DEFAULT 0 NOT NULL,
    "delivery_charge_amount" numeric(12,2) DEFAULT 0 NOT NULL,
    "print_charge_amount" numeric(12,2) DEFAULT 0 NOT NULL,
    "packing_charge_amount" numeric(12,2) DEFAULT 0 NOT NULL,
    "discount_amount" numeric(12,2) DEFAULT 0 NOT NULL,
    "is_prepaid_snapshot" boolean DEFAULT false NOT NULL,
    "delivery_instructions" "text",
    "deduct_charges_from_margin" boolean DEFAULT false NOT NULL,
    "deduct_cod_from_margin" boolean DEFAULT false NOT NULL,
    "deduct_delivery_from_margin" boolean DEFAULT false NOT NULL,
    "deduct_print_from_margin" boolean DEFAULT false NOT NULL,
    "deduct_packing_from_margin" boolean DEFAULT false NOT NULL,
    "recipient_phone_secondary" "text",
    "shipping_district" "text",
    "shipping_thana" "text",
    "cod_collect_amount" numeric(15,2),
    "package_weight_kg" numeric(8,2),
    "sender_name" "text",
    "pickup_phone" "text",
    "pickup_address" "text",
    "allow_open_box" boolean DEFAULT false,
    "driver_notes" "text",
    "courier_service_id" "uuid",
    "courier_name" "text",
    "courier_awb_number" "text",
    "tracking_url" "text",
    "delivered_at" timestamp with time zone,
    "returned_at" timestamp with time zone,
    "default_sender_name" "text",
    "default_pickup_phone" "text",
    "default_pickup_address" "text",
    "default_payout_account_type" "text",
    "default_payout_account_info" "text",
    "package_weight_band" "text" DEFAULT 'under_1kg'::"text",
    "item_category" "text",
    "parcel_description" "text",
    "courier_order_ref" "text",
    "delivery_zone" "text",
    "payout_account_type" "text" DEFAULT 'bank'::"text",
    "payout_account_info" "text",
    "delivery_instruction_notes" "text",
    "courier_tracking_number" "text",
    "courier_consignment_id" "text",
    "courier_cost_amount" numeric(12,2) DEFAULT 0.00,
    "middle_man_reference" "text",
    "courier_remittance_ref" "text",
    "courier_bank_trx_id" "text",
    "replacement_of_order_id" bigint,
    "return_charge_amount" numeric(12,2) DEFAULT 0.00,
    "deduct_return_charge_from_middle_man" boolean DEFAULT true,
    "recipient_profile_id" bigint,
    "first_offer_rate" numeric,
    "final_offer_rate" numeric,
    "return_sub_state" "text",
    "return_override_reason" "text",
    "return_ref" "text",
    "collection_source" "public"."collection_source_type",
    "payout_settlement_status" "text",
    "profit_basis" "text" DEFAULT 'total_cost'::"text",
    CONSTRAINT "shop_orders_delivery_zone_check" CHECK (("delivery_zone" = ANY (ARRAY['inside_dhaka'::"text", 'outside_dhaka'::"text"]))),
    CONSTRAINT "shop_orders_payout_settlement_status_check" CHECK ((("payout_settlement_status" IS NULL) OR ("payout_settlement_status" = ANY (ARRAY['unpaid'::"text", 'partial'::"text", 'paid'::"text"])))),
    CONSTRAINT "shop_orders_profit_basis_check" CHECK (("profit_basis" = ANY (ARRAY['purchase'::"text", 'total_cost'::"text"]))),
    CONSTRAINT "shop_orders_return_sub_state_check" CHECK (("return_sub_state" = ANY (ARRAY['return_requested'::"text", 'return_finalized'::"text"])))
);


ALTER TABLE "public"."shop_orders" OWNER TO "postgres";


COMMENT ON COLUMN "public"."shop_orders"."collection_source" IS 'Copied from linked global_invoices.collection_source for dropship COD vs prepaid gates';


COMMENT ON COLUMN "public"."shop_orders"."payout_settlement_status" IS 'Merchant profit settlement: unpaid | partial | paid (order-level)';


ALTER TABLE "public"."shop_orders" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."shop_orders_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


ALTER TABLE "public"."shop_pricing_rules" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."shop_pricing_rules_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


ALTER TABLE "public"."shop_product_listings" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."shop_product_listings_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


CREATE TABLE IF NOT EXISTS "public"."shop_product_offers" (
    "id" bigint NOT NULL,
    "shop_id" bigint NOT NULL,
    "product_id" bigint NOT NULL,
    "condition_bucket" character varying(50) DEFAULT 'normal'::character varying NOT NULL,
    "price" numeric(12,2) NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "shop_product_offers_condition_bucket_check" CHECK ((("condition_bucket")::"text" = ANY ((ARRAY['normal'::character varying, 'open_box'::character varying, 'damaged'::character varying])::"text"[]))),
    CONSTRAINT "shop_product_offers_price_check" CHECK (("price" >= (0)::numeric))
);


ALTER TABLE "public"."shop_product_offers" OWNER TO "postgres";


ALTER TABLE "public"."shop_product_offers" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."shop_product_offers_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


CREATE TABLE IF NOT EXISTS "public"."shop_stock_reservations" (
    "cart_item_id" bigint NOT NULL,
    "global_stock_allocation_id" bigint,
    "quantity" integer NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "global_stock_id" bigint,
    CONSTRAINT "shop_stock_reservations_qty_non_negative" CHECK (("quantity" >= 0))
);


ALTER TABLE "public"."shop_stock_reservations" OWNER TO "postgres";


ALTER TABLE "public"."shops" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."shops_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);




ALTER TABLE ONLY "public"."customer_group_shop_profiles"
    ADD CONSTRAINT "customer_group_shop_profiles_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."customer_group_shop_profiles"
    ADD CONSTRAINT "customer_group_shop_profiles_unique_tenant_group" UNIQUE ("tenant_id", "customer_group_id");


ALTER TABLE ONLY "public"."shop_cart_items"
    ADD CONSTRAINT "shop_cart_items_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."shop_carts"
    ADD CONSTRAINT "shop_carts_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."shop_categories"
    ADD CONSTRAINT "shop_categories_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."shop_customer_group_access"
    ADD CONSTRAINT "shop_customer_group_access_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."shop_customer_group_access"
    ADD CONSTRAINT "shop_customer_group_access_unique_shop_group" UNIQUE ("shop_id", "customer_group_id");


ALTER TABLE ONLY "public"."shop_order_items"
    ADD CONSTRAINT "shop_order_items_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."shop_orders"
    ADD CONSTRAINT "shop_orders_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."shop_pricing_rules"
    ADD CONSTRAINT "shop_pricing_rules_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."shop_pricing_rules"
    ADD CONSTRAINT "shop_pricing_rules_unique_shop" UNIQUE ("shop_id");


ALTER TABLE ONLY "public"."shop_product_listings"
    ADD CONSTRAINT "shop_product_listings_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."shop_product_listings"
    ADD CONSTRAINT "shop_product_listings_shop_stock_unique" UNIQUE ("shop_id", "global_stock_id");


ALTER TABLE ONLY "public"."shop_product_listings"
    ADD CONSTRAINT "shop_product_listings_unique_shop_alloc" UNIQUE ("shop_id", "global_stock_allocation_id");


ALTER TABLE ONLY "public"."shop_product_offers"
    ADD CONSTRAINT "shop_product_offers_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."shop_product_offers"
    ADD CONSTRAINT "shop_product_offers_shop_prod_cond_key" UNIQUE ("shop_id", "product_id", "condition_bucket");


ALTER TABLE ONLY "public"."shop_stock_reservations"
    ADD CONSTRAINT "shop_stock_reservations_pkey" PRIMARY KEY ("cart_item_id");


ALTER TABLE ONLY "public"."shops"
    ADD CONSTRAINT "shops_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."shop_categories"
    ADD CONSTRAINT "uq_shop_categories_tenant_slug" UNIQUE ("tenant_id", "slug");


CREATE INDEX "idx_shop_categories_tenant" ON "public"."shop_categories" USING "btree" ("tenant_id", "is_active");


CREATE UNIQUE INDEX "idx_shop_orders_tenant_return_ref" ON "public"."shop_orders" USING "btree" ("tenant_id", "return_ref") WHERE ("return_ref" IS NOT NULL);


CREATE INDEX "idx_shops_category_ids" ON "public"."shops" USING "gin" ("category_ids");


CREATE UNIQUE INDEX "shop_carts_active_unique_idx" ON "public"."shop_carts" USING "btree" ("tenant_id", "shop_id", "customer_group_id") WHERE ("status" = 'active'::"public"."shop_cart_status");


CREATE UNIQUE INDEX "shop_orders_order_no_unique_idx" ON "public"."shop_orders" USING "btree" ("tenant_id", "order_no");


CREATE INDEX "shop_orders_recipient_profile_id_idx" ON "public"."shop_orders" USING "btree" ("recipient_profile_id");


CREATE INDEX "shops_tenant_live_idx" ON "public"."shops" USING "btree" ("tenant_id") WHERE ("deleted_at" IS NULL);


CREATE UNIQUE INDEX "shops_unique_live_slug" ON "public"."shops" USING "btree" ("tenant_id", "slug") WHERE ("deleted_at" IS NULL);


CREATE OR REPLACE TRIGGER "trg_customer_group_shop_profiles_updated_at" BEFORE UPDATE ON "public"."customer_group_shop_profiles" FOR EACH ROW EXECUTE FUNCTION "public"."set_customer_group_shop_profiles_updated_at"();


CREATE OR REPLACE TRIGGER "trg_shop_cart_items_updated_at" BEFORE UPDATE ON "public"."shop_cart_items" FOR EACH ROW EXECUTE FUNCTION "public"."set_shop_order_updated_at"();


CREATE OR REPLACE TRIGGER "trg_shop_carts_updated_at" BEFORE UPDATE ON "public"."shop_carts" FOR EACH ROW EXECUTE FUNCTION "public"."set_shop_order_updated_at"();


CREATE OR REPLACE TRIGGER "trg_shop_customer_group_access_updated_at" BEFORE UPDATE ON "public"."shop_customer_group_access" FOR EACH ROW EXECUTE FUNCTION "public"."set_shop_customer_group_access_updated_at"();


CREATE OR REPLACE TRIGGER "trg_shop_order_items_updated_at" BEFORE UPDATE ON "public"."shop_order_items" FOR EACH ROW EXECUTE FUNCTION "public"."set_shop_order_updated_at"();


CREATE OR REPLACE TRIGGER "trg_shop_orders_updated_at" BEFORE UPDATE ON "public"."shop_orders" FOR EACH ROW EXECUTE FUNCTION "public"."set_shop_order_updated_at"();


CREATE OR REPLACE TRIGGER "trg_shop_pricing_rules_updated_at" BEFORE UPDATE ON "public"."shop_pricing_rules" FOR EACH ROW EXECUTE FUNCTION "public"."set_shop_pricing_rules_updated_at"();


CREATE OR REPLACE TRIGGER "trg_shop_product_listings_updated_at" BEFORE UPDATE ON "public"."shop_product_listings" FOR EACH ROW EXECUTE FUNCTION "public"."set_shop_product_listings_updated_at"();


CREATE OR REPLACE TRIGGER "trg_shop_stock_reservations_updated_at" BEFORE UPDATE ON "public"."shop_stock_reservations" FOR EACH ROW EXECUTE FUNCTION "public"."set_shop_order_updated_at"();


CREATE OR REPLACE TRIGGER "trg_shops_derive_is_negotiable" BEFORE INSERT OR UPDATE OF "shop_type", "is_negotiable" ON "public"."shops" FOR EACH ROW EXECUTE FUNCTION "public"."shops_derive_is_negotiable"();


CREATE OR REPLACE TRIGGER "trg_shops_updated_at" BEFORE UPDATE ON "public"."shops" FOR EACH ROW EXECUTE FUNCTION "public"."set_shops_updated_at"();


CREATE OR REPLACE TRIGGER "trg_sync_shop_cart_item_reservation" AFTER INSERT OR DELETE OR UPDATE ON "public"."shop_cart_items" FOR EACH ROW EXECUTE FUNCTION "public"."sync_shop_cart_item_reservation"();


ALTER TABLE ONLY "public"."customer_group_shop_profiles"
    ADD CONSTRAINT "customer_group_shop_profiles_customer_group_id_fkey" FOREIGN KEY ("customer_group_id") REFERENCES "public"."customer_groups"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."customer_group_shop_profiles"
    ADD CONSTRAINT "customer_group_shop_profiles_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."shop_orders"
    ADD CONSTRAINT "fk_shop_orders_courier_service" FOREIGN KEY ("courier_service_id") REFERENCES "public"."courier_services"("id") ON DELETE SET NULL;


ALTER TABLE ONLY "public"."shop_cart_items"
    ADD CONSTRAINT "shop_cart_items_cart_id_fkey" FOREIGN KEY ("cart_id") REFERENCES "public"."shop_carts"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."shop_cart_items"
    ADD CONSTRAINT "shop_cart_items_customer_sell_price_currency_id_fkey" FOREIGN KEY ("customer_sell_price_currency_id") REFERENCES "public"."global_currencies"("id");


ALTER TABLE ONLY "public"."shop_cart_items"
    ADD CONSTRAINT "shop_cart_items_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."shop_cart_items"
    ADD CONSTRAINT "shop_cart_items_unit_list_price_currency_id_fkey" FOREIGN KEY ("unit_list_price_currency_id") REFERENCES "public"."global_currencies"("id");


ALTER TABLE ONLY "public"."shop_cart_items"
    ADD CONSTRAINT "shop_cart_items_unit_minimum_sell_price_currency_id_fkey" FOREIGN KEY ("unit_minimum_sell_price_currency_id") REFERENCES "public"."global_currencies"("id");


ALTER TABLE ONLY "public"."shop_cart_items"
    ADD CONSTRAINT "shop_cart_items_unit_sell_price_currency_id_fkey" FOREIGN KEY ("unit_sell_price_currency_id") REFERENCES "public"."global_currencies"("id");


ALTER TABLE ONLY "public"."shop_carts"
    ADD CONSTRAINT "shop_carts_customer_group_id_fkey" FOREIGN KEY ("customer_group_id") REFERENCES "public"."customer_groups"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."shop_carts"
    ADD CONSTRAINT "shop_carts_shop_id_fkey" FOREIGN KEY ("shop_id") REFERENCES "public"."shops"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."shop_carts"
    ADD CONSTRAINT "shop_carts_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."shop_categories"
    ADD CONSTRAINT "shop_categories_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."shop_customer_group_access"
    ADD CONSTRAINT "shop_customer_group_access_credit_limit_currency_id_fkey" FOREIGN KEY ("credit_limit_currency_id") REFERENCES "public"."global_currencies"("id");


ALTER TABLE ONLY "public"."shop_customer_group_access"
    ADD CONSTRAINT "shop_customer_group_access_customer_group_id_fkey" FOREIGN KEY ("customer_group_id") REFERENCES "public"."customer_groups"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."shop_customer_group_access"
    ADD CONSTRAINT "shop_customer_group_access_shop_id_fkey" FOREIGN KEY ("shop_id") REFERENCES "public"."shops"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."shop_order_items"
    ADD CONSTRAINT "shop_order_items_cost_price_currency_id_fkey" FOREIGN KEY ("cost_price_currency_id") REFERENCES "public"."global_currencies"("id");


ALTER TABLE ONLY "public"."shop_order_items"
    ADD CONSTRAINT "shop_order_items_customer_offer_currency_id_fkey" FOREIGN KEY ("customer_offer_currency_id") REFERENCES "public"."global_currencies"("id");


ALTER TABLE ONLY "public"."shop_order_items"
    ADD CONSTRAINT "shop_order_items_customer_sell_price_currency_id_fkey" FOREIGN KEY ("customer_sell_price_currency_id") REFERENCES "public"."global_currencies"("id");


ALTER TABLE ONLY "public"."shop_order_items"
    ADD CONSTRAINT "shop_order_items_final_price_currency_id_fkey" FOREIGN KEY ("final_price_currency_id") REFERENCES "public"."global_currencies"("id");


ALTER TABLE ONLY "public"."shop_order_items"
    ADD CONSTRAINT "shop_order_items_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."shop_orders"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."shop_order_items"
    ADD CONSTRAINT "shop_order_items_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."shop_order_items"
    ADD CONSTRAINT "shop_order_items_staff_offer_currency_id_fkey" FOREIGN KEY ("staff_offer_currency_id") REFERENCES "public"."global_currencies"("id");


ALTER TABLE ONLY "public"."shop_order_items"
    ADD CONSTRAINT "shop_order_items_unit_list_price_currency_id_fkey" FOREIGN KEY ("unit_list_price_currency_id") REFERENCES "public"."global_currencies"("id");


ALTER TABLE ONLY "public"."shop_order_items"
    ADD CONSTRAINT "shop_order_items_unit_minimum_sell_price_currency_id_fkey" FOREIGN KEY ("unit_minimum_sell_price_currency_id") REFERENCES "public"."global_currencies"("id");


ALTER TABLE ONLY "public"."shop_order_items"
    ADD CONSTRAINT "shop_order_items_unit_sell_price_currency_id_fkey" FOREIGN KEY ("unit_sell_price_currency_id") REFERENCES "public"."global_currencies"("id");


ALTER TABLE ONLY "public"."shop_orders"
    ADD CONSTRAINT "shop_orders_billing_profile_id_fkey" FOREIGN KEY ("billing_profile_id") REFERENCES "public"."billing_profiles"("id") ON DELETE SET NULL;


ALTER TABLE ONLY "public"."shop_orders"
    ADD CONSTRAINT "shop_orders_cart_id_fkey" FOREIGN KEY ("cart_id") REFERENCES "public"."shop_carts"("id") ON DELETE SET NULL;


ALTER TABLE ONLY "public"."shop_orders"
    ADD CONSTRAINT "shop_orders_customer_group_id_fkey" FOREIGN KEY ("customer_group_id") REFERENCES "public"."customer_groups"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."shop_orders"
    ADD CONSTRAINT "shop_orders_global_invoice_id_fkey" FOREIGN KEY ("global_invoice_id") REFERENCES "public"."sales_invoices"("id") ON DELETE SET NULL;


ALTER TABLE ONLY "public"."shop_orders"
    ADD CONSTRAINT "shop_orders_recipient_profile_id_fkey" FOREIGN KEY ("recipient_profile_id") REFERENCES "public"."recipient_profiles"("id") ON DELETE RESTRICT;


ALTER TABLE ONLY "public"."shop_orders"
    ADD CONSTRAINT "shop_orders_replacement_of_order_id_fkey" FOREIGN KEY ("replacement_of_order_id") REFERENCES "public"."shop_orders"("id");


ALTER TABLE ONLY "public"."shop_orders"
    ADD CONSTRAINT "shop_orders_shop_id_fkey" FOREIGN KEY ("shop_id") REFERENCES "public"."shops"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."shop_orders"
    ADD CONSTRAINT "shop_orders_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."shop_pricing_rules"
    ADD CONSTRAINT "shop_pricing_rules_shop_id_fkey" FOREIGN KEY ("shop_id") REFERENCES "public"."shops"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."shop_pricing_rules"
    ADD CONSTRAINT "shop_pricing_rules_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."shop_product_listings"
    ADD CONSTRAINT "shop_product_listings_minimum_sell_price_currency_id_fkey" FOREIGN KEY ("minimum_sell_price_currency_id") REFERENCES "public"."global_currencies"("id");


ALTER TABLE ONLY "public"."shop_product_listings"
    ADD CONSTRAINT "shop_product_listings_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."shop_product_listings"
    ADD CONSTRAINT "shop_product_listings_sell_price_currency_id_fkey" FOREIGN KEY ("sell_price_currency_id") REFERENCES "public"."global_currencies"("id");


ALTER TABLE ONLY "public"."shop_product_listings"
    ADD CONSTRAINT "shop_product_listings_shop_id_fkey" FOREIGN KEY ("shop_id") REFERENCES "public"."shops"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."shop_product_listings"
    ADD CONSTRAINT "shop_product_listings_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."shop_product_offers"
    ADD CONSTRAINT "shop_product_offers_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."shop_product_offers"
    ADD CONSTRAINT "shop_product_offers_shop_id_fkey" FOREIGN KEY ("shop_id") REFERENCES "public"."shops"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."shop_stock_reservations"
    ADD CONSTRAINT "shop_stock_reservations_cart_item_id_fkey" FOREIGN KEY ("cart_item_id") REFERENCES "public"."shop_cart_items"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."shops"
    ADD CONSTRAINT "shops_buy_currency_id_fkey" FOREIGN KEY ("buy_currency_id") REFERENCES "public"."global_currencies"("id");


ALTER TABLE ONLY "public"."shops"
    ADD CONSTRAINT "shops_default_currency_id_fkey" FOREIGN KEY ("default_currency_id") REFERENCES "public"."global_currencies"("id");


ALTER TABLE ONLY "public"."shops"
    ADD CONSTRAINT "shops_sell_currency_id_fkey" FOREIGN KEY ("sell_currency_id") REFERENCES "public"."global_currencies"("id");


ALTER TABLE ONLY "public"."shops"
    ADD CONSTRAINT "shops_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


CREATE OR REPLACE TRIGGER "trg_restock_dropship_order_on_delete" BEFORE DELETE ON "public"."shop_orders" FOR EACH ROW EXECUTE FUNCTION "public"."restock_dropship_order_on_delete"();


CREATE TABLE IF NOT EXISTS "public"."customer_demand_bucket_items" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "billing_profile_id" bigint NOT NULL,
    "product_id" bigint NOT NULL,
    "source_type" "public"."demand_bucket_source_type" NOT NULL,
    "source_id" bigint,
    "name" "text" NOT NULL,
    "image_url" "text",
    "barcode" "text",
    "product_code" "text",
    "note" "text",
    "quantity" integer DEFAULT 1 NOT NULL,
    "status" "public"."demand_bucket_status" DEFAULT 'open'::"public"."demand_bucket_status" NOT NULL,
    "popped_at" timestamp with time zone,
    "popped_into_type" "text",
    "popped_into_id" bigint,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "customer_demand_bucket_items_quantity_check" CHECK (("quantity" > 0))
);


ALTER TABLE "public"."customer_demand_bucket_items" OWNER TO "postgres";


ALTER TABLE "public"."customer_demand_bucket_items" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."customer_demand_bucket_items_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


ALTER TABLE ONLY "public"."customer_demand_bucket_items"
    ADD CONSTRAINT "customer_demand_bucket_items_pkey" PRIMARY KEY ("id");


CREATE INDEX "idx_demand_bucket_open_profile" ON "public"."customer_demand_bucket_items" USING "btree" ("tenant_id", "billing_profile_id") WHERE ("status" = 'open'::"public"."demand_bucket_status");


CREATE INDEX "idx_demand_bucket_popped_purge" ON "public"."customer_demand_bucket_items" USING "btree" ("popped_at") WHERE ("status" = 'popped'::"public"."demand_bucket_status");


CREATE INDEX "idx_demand_bucket_source" ON "public"."customer_demand_bucket_items" USING "btree" ("source_type", "source_id") WHERE ("source_id" IS NOT NULL);


ALTER TABLE ONLY "public"."customer_demand_bucket_items"
    ADD CONSTRAINT "customer_demand_bucket_items_billing_profile_id_fkey" FOREIGN KEY ("billing_profile_id") REFERENCES "public"."billing_profiles"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."customer_demand_bucket_items"
    ADD CONSTRAINT "customer_demand_bucket_items_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."customer_demand_bucket_items"
    ADD CONSTRAINT "customer_demand_bucket_items_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


CREATE OR REPLACE TRIGGER "trg_customer_demand_bucket_items_set_updated_at" BEFORE UPDATE ON "public"."customer_demand_bucket_items" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE TABLE IF NOT EXISTS "public"."dropship_order_settlements" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "shop_order_id" bigint NOT NULL,
    "billing_profile_id" bigint,
    "currency_id" bigint,
    "calculated_cod_amount" numeric(15,2) DEFAULT 0 NOT NULL,
    "collected_cod_amount" numeric(15,2) DEFAULT 0 NOT NULL,
    "reseller_unit_purchase_cost" numeric(15,2) DEFAULT 0 NOT NULL,
    "reseller_purchase_cost" numeric(15,2) DEFAULT 0 NOT NULL,
    "discount_company_pay" numeric(15,2) DEFAULT 0 NOT NULL,
    "return_reason_note" "text",
    "total_cost" numeric(15,2),
    "reseller_profit" numeric(15,2),
    "company_profit" numeric(15,2),
    "status" "public"."dropship_settlement_status" DEFAULT 'draft'::"public"."dropship_settlement_status" NOT NULL,
    "confirmed_at" timestamp with time zone,
    "confirmed_by" "uuid",
    "courier_cod_booked_at" timestamp with time zone,
    "remittance_at" timestamp with time zone,
    "merchant_payout_at" timestamp with time zone,
    "wallet_ledger_batch_id" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."dropship_order_settlements" OWNER TO "postgres";


ALTER TABLE "public"."dropship_order_settlements" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."dropship_order_settlements_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


CREATE TABLE IF NOT EXISTS "public"."dropship_settlement_charge_lines" (
    "id" bigint NOT NULL,
    "settlement_id" bigint NOT NULL,
    "charge_type" "public"."dropship_settlement_charge_type" NOT NULL,
    "amount" numeric(15,2) DEFAULT 0 NOT NULL,
    "payer" "public"."dropship_settlement_charge_payer" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."dropship_settlement_charge_lines" OWNER TO "postgres";


ALTER TABLE "public"."dropship_settlement_charge_lines" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."dropship_settlement_charge_lines_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


ALTER TABLE ONLY "public"."dropship_order_settlements"
    ADD CONSTRAINT "dropship_order_settlements_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."dropship_order_settlements"
    ADD CONSTRAINT "dropship_order_settlements_shop_order_id_key" UNIQUE ("shop_order_id");


CREATE INDEX "idx_dropship_order_settlements_tenant" ON "public"."dropship_order_settlements" USING "btree" ("tenant_id");


ALTER TABLE ONLY "public"."dropship_settlement_charge_lines"
    ADD CONSTRAINT "dropship_settlement_charge_lines_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."dropship_settlement_charge_lines"
    ADD CONSTRAINT "dropship_settlement_charge_lines_settlement_charge_type_key" UNIQUE ("settlement_id", "charge_type");


CREATE INDEX "idx_dropship_settlement_charge_lines_settlement" ON "public"."dropship_settlement_charge_lines" USING "btree" ("settlement_id");


ALTER TABLE ONLY "public"."dropship_order_settlements"
    ADD CONSTRAINT "dropship_order_settlements_billing_profile_id_fkey" FOREIGN KEY ("billing_profile_id") REFERENCES "public"."billing_profiles"("id") ON DELETE SET NULL;


ALTER TABLE ONLY "public"."dropship_order_settlements"
    ADD CONSTRAINT "dropship_order_settlements_currency_id_fkey" FOREIGN KEY ("currency_id") REFERENCES "public"."global_currencies"("id") ON DELETE SET NULL;


ALTER TABLE ONLY "public"."dropship_order_settlements"
    ADD CONSTRAINT "dropship_order_settlements_shop_order_id_fkey" FOREIGN KEY ("shop_order_id") REFERENCES "public"."shop_orders"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."dropship_order_settlements"
    ADD CONSTRAINT "dropship_order_settlements_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."dropship_settlement_charge_lines"
    ADD CONSTRAINT "dropship_settlement_charge_lines_settlement_id_fkey" FOREIGN KEY ("settlement_id") REFERENCES "public"."dropship_order_settlements"("id") ON DELETE CASCADE;


CREATE OR REPLACE TRIGGER "trg_dropship_order_settlements_set_updated_at" BEFORE UPDATE ON "public"."dropship_order_settlements" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_dropship_settlement_charge_lines_set_updated_at" BEFORE UPDATE ON "public"."dropship_settlement_charge_lines" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();

