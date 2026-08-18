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
    'shelf',
    'slot',
    'box',
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


