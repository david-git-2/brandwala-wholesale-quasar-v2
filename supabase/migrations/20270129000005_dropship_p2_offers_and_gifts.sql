-- Migration: 20270129000005_dropship_p2_offers_and_gifts.sql
-- Description: Phase P2 Gaps - Condition-segmented offer pricing table & customer-group gift rules schema

BEGIN;

-- 1. Create shop_product_offers table for unified customer-facing condition pricing
CREATE TABLE IF NOT EXISTS public.shop_product_offers (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    shop_id BIGINT NOT NULL REFERENCES public.shops(id) ON DELETE CASCADE,
    product_id BIGINT NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    condition_bucket VARCHAR(50) NOT NULL DEFAULT 'normal' CHECK (condition_bucket IN ('normal', 'open_box', 'damaged')),
    price NUMERIC(12, 2) NOT NULL CHECK (price >= 0),
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT shop_product_offers_shop_prod_cond_key UNIQUE (shop_id, product_id, condition_bucket)
);

-- RLS for shop_product_offers
ALTER TABLE public.shop_product_offers ENABLE ROW LEVEL SECURITY;

CREATE POLICY shop_product_offers_select ON public.shop_product_offers
    FOR SELECT USING (true);

CREATE POLICY shop_product_offers_all_staff ON public.shop_product_offers
    FOR ALL USING (auth.role() = 'authenticated');

-- 2. Create customer-group gift program rules & redemptions schema
CREATE TABLE IF NOT EXISTS public.gift_rules (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    customer_group_id BIGINT REFERENCES public.customer_groups(id) ON DELETE CASCADE,
    cost_ownership VARCHAR(50) NOT NULL DEFAULT 'tenant' CHECK (cost_ownership IN ('tenant', 'middleman', 'split')),
    priority INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.gift_rule_items (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    rule_id BIGINT NOT NULL REFERENCES public.gift_rules(id) ON DELETE CASCADE,
    product_id BIGINT NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    quantity INT NOT NULL DEFAULT 1 CHECK (quantity > 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.gift_rule_redemptions (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id BIGINT NOT NULL REFERENCES public.shop_orders(id) ON DELETE CASCADE,
    rule_id BIGINT NOT NULL REFERENCES public.gift_rules(id) ON DELETE CASCADE,
    redeemed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT gift_rule_redemptions_order_rule_key UNIQUE (order_id, rule_id)
);

-- RLS for gift rules
ALTER TABLE public.gift_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gift_rule_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gift_rule_redemptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY gift_rules_select ON public.gift_rules FOR SELECT USING (true);
CREATE POLICY gift_rules_all_staff ON public.gift_rules FOR ALL USING (auth.role() = 'authenticated');

CREATE POLICY gift_rule_items_select ON public.gift_rule_items FOR SELECT USING (true);
CREATE POLICY gift_rule_items_all_staff ON public.gift_rule_items FOR ALL USING (auth.role() = 'authenticated');

CREATE POLICY gift_rule_redemptions_select ON public.gift_rule_redemptions FOR SELECT USING (true);
CREATE POLICY gift_rule_redemptions_all_staff ON public.gift_rule_redemptions FOR ALL USING (auth.role() = 'authenticated');

COMMIT;
