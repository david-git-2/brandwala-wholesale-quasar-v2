-- Extracted from supabase/schemas/public.sql (procurement/stock/costing). Move-only.

CREATE TYPE "public"."costing_file_item_status" AS ENUM (
    'pending',
    'accepted',
    'rejected'
);


ALTER TYPE "public"."costing_file_item_status" OWNER TO "postgres";


CREATE TYPE "public"."costing_file_status" AS ENUM (
    'draft',
    'customer_submitted',
    'in_review',
    'priced',
    'offered',
    'accepted',
    'po_placed',
    'cancelled',
    'completed'
);


ALTER TYPE "public"."costing_file_status" OWNER TO "postgres";


CREATE TYPE "public"."global_shipment_cost_type" AS ENUM (
    'product',
    'cargo',
    'duty',
    'insurance',
    'labor',
    'washing',
    'transport',
    'handling'
);


ALTER TYPE "public"."global_shipment_cost_type" OWNER TO "postgres";


CREATE TYPE "public"."global_shipment_item_add_method" AS ENUM (
    'order',
    'costing',
    'manual'
);


ALTER TYPE "public"."global_shipment_item_add_method" OWNER TO "postgres";


CREATE TYPE "public"."global_shipment_type" AS ENUM (
    'local',
    'international',
    'transfer',
    'thrift'
);


ALTER TYPE "public"."global_shipment_type" OWNER TO "postgres";


CREATE TYPE "public"."global_shipment_outcome_kind" AS ENUM (
    'sellable',
    'unsellable'
);


ALTER TYPE "public"."global_shipment_outcome_kind" OWNER TO "postgres";


CREATE TYPE "public"."global_shipment_outcome_reason" AS ENUM (
    'general',
    'vendor_discount',
    'missing',
    'damaged',
    'other',
    'ordered'
);


ALTER TYPE "public"."global_shipment_outcome_reason" OWNER TO "postgres";


CREATE TYPE "public"."shipment_investment_status" AS ENUM (
    'active',
    'closed',
    'cancelled'
);


ALTER TYPE "public"."shipment_investment_status" OWNER TO "postgres";


CREATE TYPE "public"."stock_availability" AS ENUM (
    'sellable',
    'held',
    'unsellable'
);


ALTER TYPE "public"."stock_availability" OWNER TO "postgres";


CREATE TYPE "public"."stock_location_kind" AS ENUM (
    'warehouse',
    'zone',
    'shelf',
    'level',
    'bin',
    'returns'
);


ALTER TYPE "public"."stock_location_kind" OWNER TO "postgres";


CREATE TYPE "public"."stock_movement_type" AS ENUM (
    'adjustment',
    'location_transfer',
    'availability_transfer',
    'receive_putaway',
    'return_inbound',
    'receive_rollback',
    'vendor_return',
    'grade_change'
);


ALTER TYPE "public"."stock_movement_type" OWNER TO "postgres";


CREATE TYPE "public"."preorder_demand_source_type" AS ENUM (
    'shop_order_item',
    'pbc_costing_item'
);


ALTER TYPE "public"."preorder_demand_source_type" OWNER TO "postgres";


CREATE TYPE "public"."pbc_offer_pricing_mode" AS ENUM (
    'landed_cost_plus',
    'gbp_vat_then_profit'
);


ALTER TYPE "public"."pbc_offer_pricing_mode" OWNER TO "postgres";


