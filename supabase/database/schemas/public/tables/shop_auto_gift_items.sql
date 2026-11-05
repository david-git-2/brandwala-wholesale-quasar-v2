CREATE TABLE public.shop_auto_gift_items (
  id                   bigint                   GENERATED ALWAYS AS IDENTITY NOT NULL,
  tenant_id            bigint                   NOT NULL,
  shop_id              bigint                   NOT NULL,
  product_id           bigint                   NOT NULL,
  quantity             integer                  DEFAULT 1 NOT NULL,
  gift_source          text                     NOT NULL,
  gift_cost_amount     numeric(12,4)            DEFAULT 0 NOT NULL,
  gift_cost_charged_to text,
  is_active            boolean                  DEFAULT true NOT NULL,
  created_at           timestamp with time zone DEFAULT now() NOT NULL,
  updated_at           timestamp with time zone DEFAULT now() NOT NULL
);

CREATE INDEX idx_shop_auto_gift_items_shop_id ON public.shop_auto_gift_items (shop_id);

CREATE POLICY shop_auto_gift_items_staff_all ON public.shop_auto_gift_items
  USING (public.is_tenant_staff(tenant_id))
  WITH CHECK (public.is_tenant_staff(tenant_id));

CREATE POLICY shop_auto_gift_items_superadmin_all ON public.shop_auto_gift_items
  USING ((EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE ((lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.role = 'superadmin'::public.app_role) AND (m.is_active = true)))));

ALTER TABLE public.shop_auto_gift_items
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.shop_auto_gift_items
  ADD CONSTRAINT shop_auto_gift_items_charged_to_check CHECK (gift_cost_charged_to IS NULL OR (gift_cost_charged_to = ANY (ARRAY['reseller'::text, 'tenant'::text])));

ALTER TABLE public.shop_auto_gift_items
  ADD CONSTRAINT shop_auto_gift_items_gift_source_check CHECK (gift_source = ANY (ARRAY['stock'::text, 'customer_stock'::text]));

ALTER TABLE public.shop_auto_gift_items
  ADD CONSTRAINT shop_auto_gift_items_pkey PRIMARY KEY (id);

ALTER TABLE public.shop_auto_gift_items
  ADD CONSTRAINT shop_auto_gift_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE RESTRICT;

ALTER TABLE public.shop_auto_gift_items
  ADD CONSTRAINT shop_auto_gift_items_qty_positive CHECK (quantity > 0);

ALTER TABLE public.shop_auto_gift_items
  ADD CONSTRAINT shop_auto_gift_items_shop_id_fkey FOREIGN KEY (shop_id) REFERENCES public.shops(id) ON DELETE CASCADE;

ALTER TABLE public.shop_auto_gift_items
  ADD CONSTRAINT shop_auto_gift_items_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.shop_auto_gift_items TO anon;

GRANT ALL ON public.shop_auto_gift_items TO authenticated;

GRANT ALL ON public.shop_auto_gift_items TO service_role;