CREATE TABLE public.shop_customer_stocks (
  id                bigint                   GENERATED ALWAYS AS IDENTITY NOT NULL,
  tenant_id         bigint                   NOT NULL,
  shop_id           bigint                   NOT NULL,
  product_id        bigint,
  quantity_on_hand  integer                  DEFAULT 0 NOT NULL,
  created_at        timestamp with time zone DEFAULT now() NOT NULL,
  updated_at        timestamp with time zone DEFAULT now() NOT NULL,
  customer_group_id bigint,
  item_label        text
);

CREATE INDEX idx_shop_customer_stocks_shop_group ON public.shop_customer_stocks (shop_id, customer_group_id);

CREATE INDEX idx_shop_customer_stocks_shop_id ON public.shop_customer_stocks (shop_id);

CREATE UNIQUE INDEX shop_customer_stocks_shop_group_label_key ON public.shop_customer_stocks (shop_id, customer_group_id, lower(TRIM(BOTH FROM item_label)))
  WHERE product_id IS NULL AND item_label IS NOT NULL;

CREATE UNIQUE INDEX shop_customer_stocks_shop_group_product_key ON public.shop_customer_stocks (shop_id, customer_group_id, product_id)
  WHERE product_id IS NOT NULL;

CREATE POLICY shop_customer_stocks_staff_all ON public.shop_customer_stocks
  USING (public.is_tenant_staff(tenant_id))
  WITH CHECK (public.is_tenant_staff(tenant_id));

CREATE POLICY shop_customer_stocks_superadmin_all ON public.shop_customer_stocks
  USING ((EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE ((lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.role = 'superadmin'::public.app_role) AND (m.is_active = true)))));

ALTER TABLE public.shop_customer_stocks
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.shop_customer_stocks
  ADD CONSTRAINT shop_customer_stocks_customer_group_id_fkey FOREIGN KEY (customer_group_id) REFERENCES public.customer_groups(id) ON DELETE CASCADE;

ALTER TABLE public.shop_customer_stocks
  ADD CONSTRAINT shop_customer_stocks_pkey PRIMARY KEY (id);

ALTER TABLE public.shop_customer_stocks
  ADD CONSTRAINT shop_customer_stocks_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE RESTRICT;

ALTER TABLE public.shop_customer_stocks
  ADD CONSTRAINT shop_customer_stocks_product_or_label_check CHECK (product_id IS NOT NULL OR item_label IS NOT NULL AND length(TRIM(BOTH FROM item_label)) > 0);

ALTER TABLE public.shop_customer_stocks
  ADD CONSTRAINT shop_customer_stocks_qty_non_negative CHECK (quantity_on_hand >= 0);

ALTER TABLE public.shop_customer_stocks
  ADD CONSTRAINT shop_customer_stocks_shop_id_fkey FOREIGN KEY (shop_id) REFERENCES public.shops(id) ON DELETE CASCADE;

ALTER TABLE public.shop_customer_stocks
  ADD CONSTRAINT shop_customer_stocks_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.shop_customer_stocks TO anon;

GRANT ALL ON public.shop_customer_stocks TO authenticated;

GRANT ALL ON public.shop_customer_stocks TO service_role;