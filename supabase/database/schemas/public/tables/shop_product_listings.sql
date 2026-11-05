CREATE TABLE public.shop_product_listings (
  id                             bigint                   GENERATED ALWAYS AS IDENTITY NOT NULL,
  tenant_id                      bigint                   NOT NULL,
  shop_id                        bigint                   NOT NULL,
  global_stock_allocation_id     bigint,
  global_stock_id                bigint,
  product_id                     bigint                   NOT NULL,
  sell_price_amount              numeric(12,4)            NOT NULL,
  sell_price_currency_id         bigint                   NOT NULL,
  minimum_sell_price_amount      numeric(12,4)            DEFAULT NULL::numeric,
  minimum_sell_price_currency_id bigint,
  show_quantity                  boolean,
  display_quantity_override      integer,
  is_active                      boolean                  DEFAULT true NOT NULL,
  created_at                     timestamp with time zone DEFAULT now() NOT NULL,
  updated_at                     timestamp with time zone DEFAULT now() NOT NULL,
  is_price_locked                boolean                  DEFAULT false NOT NULL,
  is_quantity_locked             boolean                  DEFAULT false NOT NULL,
  quantity_override_type         text                     DEFAULT 'absolute'::text NOT NULL,
  grade_tag_id                   bigint
);

CREATE UNIQUE INDEX shop_product_listings_shop_product_grade_unique ON public.shop_product_listings (shop_id, product_id, grade_tag_id)
  WHERE grade_tag_id IS NOT NULL;

CREATE UNIQUE INDEX shop_product_listings_shop_product_draft_unique ON public.shop_product_listings (shop_id, product_id)
  WHERE global_stock_id IS NULL;

CREATE TRIGGER trg_shop_product_listings_updated_at
  BEFORE UPDATE ON public.shop_product_listings
  FOR EACH ROW
  EXECUTE FUNCTION public.set_shop_product_listings_updated_at();

CREATE POLICY listings_select_tenant_member ON public.shop_product_listings
  FOR SELECT
  USING ((tenant_id IN ( SELECT tm.tenant_id
   FROM public.memberships tm
  WHERE ((lower(TRIM(BOTH FROM tm.email)) = public.current_user_email()) AND (tm.is_active = true)))));

CREATE POLICY listings_superadmin_all ON public.shop_product_listings
  USING ((EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE ((lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.role = 'superadmin'::public.app_role) AND (m.is_active = true)))));

CREATE POLICY listings_write_tenant_admin_staff ON public.shop_product_listings
  USING ((tenant_id IN ( SELECT m.tenant_id
   FROM public.memberships m
  WHERE ((lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.role = ANY (ARRAY['admin'::public.app_role, 'staff'::public.app_role])) AND (m.is_active = true)))));

ALTER TABLE public.shop_product_listings
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.shop_product_listings
  ADD CONSTRAINT shop_product_listings_global_stock_id_fkey FOREIGN KEY (global_stock_id) REFERENCES public.global_stocks(id) ON DELETE CASCADE;

ALTER TABLE public.shop_product_listings
  ADD CONSTRAINT shop_product_listings_min_sell_currency CHECK ((minimum_sell_price_amount IS NULL) = (minimum_sell_price_currency_id IS NULL));

ALTER TABLE public.shop_product_listings
  ADD CONSTRAINT shop_product_listings_minimum_sell_price_currency_id_fkey FOREIGN KEY (minimum_sell_price_currency_id) REFERENCES public.global_currencies(id);

ALTER TABLE public.shop_product_listings
  ADD CONSTRAINT shop_product_listings_pkey PRIMARY KEY (id);

ALTER TABLE public.shop_product_listings
  ADD CONSTRAINT shop_product_listings_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE CASCADE;

ALTER TABLE public.shop_product_listings
  ADD CONSTRAINT shop_product_listings_qty_override_type_check CHECK (quantity_override_type = ANY (ARRAY['absolute'::text, 'relative'::text]));

ALTER TABLE public.shop_product_listings
  ADD CONSTRAINT shop_product_listings_sell_price_currency_id_fkey FOREIGN KEY (sell_price_currency_id) REFERENCES public.global_currencies(id);

ALTER TABLE public.shop_product_listings
  ADD CONSTRAINT shop_product_listings_shop_stock_unique UNIQUE (shop_id, global_stock_id);

ALTER TABLE public.shop_product_listings
  ADD CONSTRAINT shop_product_listings_unique_shop_alloc UNIQUE (shop_id, global_stock_allocation_id);

ALTER TABLE public.shop_product_listings
  ADD CONSTRAINT shop_product_listings_shop_id_fkey FOREIGN KEY (shop_id) REFERENCES public.shops(id) ON DELETE CASCADE;

ALTER TABLE public.shop_product_listings
  ADD CONSTRAINT shop_product_listings_grade_tag_id_fkey FOREIGN KEY (grade_tag_id) REFERENCES public.tags(id);

ALTER TABLE public.shop_product_listings
  ADD CONSTRAINT shop_product_listings_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.shop_product_listings TO anon;

GRANT ALL ON public.shop_product_listings TO authenticated;

GRANT ALL ON public.shop_product_listings TO service_role;