-- Extracted from supabase/schemas/public.sql (shop_order). Move-only.

CREATE TYPE "public"."shop_cart_status" AS ENUM (
    'active',
    'converted',
    'abandoned'
);


ALTER TYPE "public"."shop_cart_status" OWNER TO "postgres";


CREATE TYPE "public"."shop_order_mode_enum" AS ENUM (
    'procurement_intent',
    'checkout_fixed',
    'checkout_wholesale'
);


ALTER TYPE "public"."shop_order_mode_enum" OWNER TO "postgres";


CREATE TYPE "public"."shop_order_status" AS ENUM (
    'draft',
    'submitted',
    'cancelled',
    'priced',
    'negotiating',
    'confirmed',
    'placed',
    'fulfilled',
    'processing',
    'shipped',
    'delivered',
    'payment_received',
    'ready_for_pickup',
    'returned',
    'costing_pending',
    'countered',
    'final_offered',
    'procuring',
    'ordered'
);


ALTER TYPE "public"."shop_order_status" OWNER TO "postgres";


CREATE TYPE "public"."shop_type_enum" AS ENUM (
    'vendor_catalog',
    'fixed_price',
    'dropship'
);


ALTER TYPE "public"."shop_type_enum" OWNER TO "postgres";


