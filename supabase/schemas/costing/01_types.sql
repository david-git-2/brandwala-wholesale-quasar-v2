-- Costing file domain enum types (moved out of monolithic public schema; matches baseline.sql)

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
