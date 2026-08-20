-- Extracted from supabase/schemas/public.sql (sales_invoice). Move-only.

CREATE TYPE "public"."collection_source_type" AS ENUM (
    'billing_profile',
    'recipient'
);

ALTER TYPE "public"."collection_source_type" OWNER TO "postgres";


CREATE TYPE "public"."global_fulfillment_status" AS ENUM (
    'pending',
    'packed',
    'shipped',
    'delivered'
);

ALTER TYPE "public"."global_fulfillment_status" OWNER TO "postgres";


CREATE TYPE "public"."global_invoice_status" AS ENUM (
    'draft',
    'posted',
    'voided'
);

ALTER TYPE "public"."global_invoice_status" OWNER TO "postgres";


CREATE TYPE "public"."global_invoice_type" AS ENUM (
    'wholesale',
    'retail',
    'dropship'
);

ALTER TYPE "public"."global_invoice_type" OWNER TO "postgres";


CREATE TYPE "public"."global_source_module" AS ENUM (
    'wholesale',
    'retail',
    'commerce'
);

ALTER TYPE "public"."global_source_module" OWNER TO "postgres";


CREATE TYPE "public"."invoice_charge_type" AS ENUM (
    'cod',
    'packing',
    'print',
    'delivery',
    'other'
);

ALTER TYPE "public"."invoice_charge_type" OWNER TO "postgres";


CREATE TYPE "public"."retail_billing_mode" AS ENUM (
    'account',
    'direct'
);

ALTER TYPE "public"."retail_billing_mode" OWNER TO "postgres";
