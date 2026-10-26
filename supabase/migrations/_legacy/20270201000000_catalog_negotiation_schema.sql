-- Migration: Phase P0 — Catalog Negotiation Schema
-- File: supabase/migrations/20270201000000_catalog_negotiation_schema.sql

-- 1. Add new enum values to shop_order_status if they do not exist
ALTER TYPE shop_order_status ADD VALUE IF NOT EXISTS 'costing_pending';
ALTER TYPE shop_order_status ADD VALUE IF NOT EXISTS 'countered';
ALTER TYPE shop_order_status ADD VALUE IF NOT EXISTS 'final_offered';
ALTER TYPE shop_order_status ADD VALUE IF NOT EXISTS 'procuring';
ALTER TYPE shop_order_status ADD VALUE IF NOT EXISTS 'ordered';

-- 2. Add profit_basis column to shop_orders
ALTER TABLE shop_orders 
ADD COLUMN IF NOT EXISTS profit_basis text DEFAULT 'total_cost' CHECK (profit_basis IN ('purchase', 'total_cost'));

-- 3. Add catalog negotiation fields to shop_order_items
ALTER TABLE shop_order_items
ADD COLUMN IF NOT EXISTS confirmed_quantity integer,
ADD COLUMN IF NOT EXISTS weight_kg numeric(12,4),
ADD COLUMN IF NOT EXISTS cost_price_amount numeric(12,4),
ADD COLUMN IF NOT EXISTS cost_price_currency_id bigint REFERENCES global_currencies(id),
ADD COLUMN IF NOT EXISTS customer_decision_status text DEFAULT 'pending',
ADD COLUMN IF NOT EXISTS customer_decision_at timestamptz,
ADD COLUMN IF NOT EXISTS negotiation_status text DEFAULT 'pending',
ADD COLUMN IF NOT EXISTS staff_offer_at timestamptz,
ADD COLUMN IF NOT EXISTS customer_counter_at timestamptz,
ADD COLUMN IF NOT EXISTS final_offer_at timestamptz;

-- 4. Create table customer_order_backlog_items
CREATE TABLE IF NOT EXISTS customer_order_backlog_items (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tenant_id bigint NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    billing_profile_id bigint NOT NULL REFERENCES billing_profiles(id) ON DELETE CASCADE,
    product_id bigint NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    order_id bigint REFERENCES shop_orders(id) ON DELETE SET NULL,
    order_item_id bigint REFERENCES shop_order_items(id) ON DELETE SET NULL,
    requested_quantity integer NOT NULL CHECK (requested_quantity > 0),
    fulfilled_quantity integer NOT NULL DEFAULT 0 CHECK (fulfilled_quantity >= 0),
    backlog_status text NOT NULL DEFAULT 'open' CHECK (backlog_status IN ('open', 'partially_fulfilled', 'fulfilled', 'cancelled')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_customer_backlog_item UNIQUE (tenant_id, billing_profile_id, product_id)
);

-- RLS for customer_order_backlog_items
ALTER TABLE customer_order_backlog_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY customer_order_backlog_items_tenant_isolation ON customer_order_backlog_items
    FOR ALL
    USING (tenant_id = (current_setting('app.current_tenant_id', true))::bigint);

-- Notify schema reload
NOTIFY pgrst, 'reload schema';
