-- Thrift domain enum types (moved out of monolithic public schema; matches baseline.sql)

CREATE TYPE "public"."thrift_condition" AS ENUM (
    'NEW_WITH_TAGS',
    'EXCELLENT',
    'GOOD',
    'FAIR'
);

ALTER TYPE "public"."thrift_condition" OWNER TO "postgres";

CREATE TYPE "public"."thrift_delivery_status" AS ENUM (
    'PENDING',
    'SHIPPED',
    'DELIVERED',
    'RETURNED',
    'PARTIALLY_RETURNED'
);

ALTER TYPE "public"."thrift_delivery_status" OWNER TO "postgres";

CREATE TYPE "public"."thrift_item_status" AS ENUM (
    'SOLD',
    'RETURNED'
);

ALTER TYPE "public"."thrift_item_status" OWNER TO "postgres";

CREATE TYPE "public"."thrift_ledger_source" AS ENUM (
    'INVOICE',
    'SHIPMENT',
    'OPERATIONAL'
);

ALTER TYPE "public"."thrift_ledger_source" OWNER TO "postgres";

CREATE TYPE "public"."thrift_ledger_type" AS ENUM (
    'REVENUE',
    'EXPENSE',
    'REFUND',
    'LOSS'
);

ALTER TYPE "public"."thrift_ledger_type" OWNER TO "postgres";

CREATE TYPE "public"."thrift_payment_status" AS ENUM (
    'UNPAID',
    'PAID',
    'REFUNDED'
);

ALTER TYPE "public"."thrift_payment_status" OWNER TO "postgres";

CREATE TYPE "public"."thrift_return_action" AS ENUM (
    'RESTOCK',
    'WRITE_OFF'
);

ALTER TYPE "public"."thrift_return_action" OWNER TO "postgres";

CREATE TYPE "public"."thrift_section" AS ENUM (
    'MALE',
    'FEMALE',
    'UNISEX',
    'KIDS',
    'HOME'
);

ALTER TYPE "public"."thrift_section" OWNER TO "postgres";

CREATE TYPE "public"."thrift_stock_status" AS ENUM (
    'AVAILABLE',
    'OUT_OF_STOCK',
    'DAMAGED',
    'STOLEN',
    'SOLD',
    'RESERVED'
);

ALTER TYPE "public"."thrift_stock_status" OWNER TO "postgres";

CREATE TYPE "public"."thrift_stock_type" AS ENUM (
    'SINGLE',
    'BULK'
);

ALTER TYPE "public"."thrift_stock_type" OWNER TO "postgres";

CREATE TYPE "public"."thrift_transaction_method" AS ENUM (
    'CASH',
    'CARD',
    'MOBILE_BANKING',
    'COD'
);

ALTER TYPE "public"."thrift_transaction_method" OWNER TO "postgres";
