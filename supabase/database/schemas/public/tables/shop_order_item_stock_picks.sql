CREATE TABLE public.shop_order_item_stock_picks (
  id               bigint                   GENERATED ALWAYS AS IDENTITY NOT NULL,
  tenant_id        bigint                   NOT NULL,
  order_id         bigint                   NOT NULL,
  order_item_id    bigint                   NOT NULL,
  global_stock_id  bigint                   NOT NULL,
  shipment_item_id bigint                   NOT NULL,
  shipment_id      bigint                   NOT NULL,
  quantity         integer                  NOT NULL,
  held_stock_id    bigint,
  created_by_email text,
  created_at       timestamp with time zone DEFAULT now() NOT NULL,
  updated_at       timestamp with time zone DEFAULT now() NOT NULL
);

CREATE INDEX idx_shop_order_item_stock_picks_order_item_id ON public.shop_order_item_stock_picks (order_item_id);

CREATE INDEX idx_shop_order_item_stock_picks_global_stock_id ON public.shop_order_item_stock_picks (global_stock_id);

CREATE INDEX idx_shop_order_item_stock_picks_order_id ON public.shop_order_item_stock_picks (order_id);

CREATE INDEX idx_shop_order_item_stock_picks_tenant_id ON public.shop_order_item_stock_picks (tenant_id);

CREATE POLICY shop_order_item_stock_picks_staff_all ON public.shop_order_item_stock_picks
  USING (public.is_tenant_staff(tenant_id))
  WITH CHECK (public.is_tenant_staff(tenant_id));

ALTER TABLE public.shop_order_item_stock_picks
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.shop_order_item_stock_picks
  ADD CONSTRAINT shop_order_item_stock_picks_global_stock_id_fkey FOREIGN KEY (global_stock_id) REFERENCES public.global_stocks(id) ON DELETE CASCADE;

ALTER TABLE public.shop_order_item_stock_picks
  ADD CONSTRAINT shop_order_item_stock_picks_held_stock_id_fkey FOREIGN KEY (held_stock_id) REFERENCES public.global_stocks(id) ON DELETE SET NULL;

ALTER TABLE public.shop_order_item_stock_picks
  ADD CONSTRAINT shop_order_item_stock_picks_order_item_id_global_stock_id_key UNIQUE (order_item_id, global_stock_id);

ALTER TABLE public.shop_order_item_stock_picks
  ADD CONSTRAINT shop_order_item_stock_picks_pkey PRIMARY KEY (id);

ALTER TABLE public.shop_order_item_stock_picks
  ADD CONSTRAINT shop_order_item_stock_picks_quantity_check CHECK (quantity > 0);

ALTER TABLE public.shop_order_item_stock_picks
  ADD CONSTRAINT shop_order_item_stock_picks_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.global_shipments(id) ON DELETE CASCADE;

ALTER TABLE public.shop_order_item_stock_picks
  ADD CONSTRAINT shop_order_item_stock_picks_shipment_item_id_fkey FOREIGN KEY (shipment_item_id) REFERENCES public.global_shipment_items(id) ON DELETE CASCADE;

ALTER TABLE public.shop_order_item_stock_picks
  ADD CONSTRAINT shop_order_item_stock_picks_order_item_id_fkey FOREIGN KEY (order_item_id) REFERENCES public.shop_order_items(id) ON DELETE CASCADE;

ALTER TABLE public.shop_order_item_stock_picks
  ADD CONSTRAINT shop_order_item_stock_picks_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.shop_orders(id) ON DELETE CASCADE;

ALTER TABLE public.shop_order_item_stock_picks
  ADD CONSTRAINT shop_order_item_stock_picks_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.shop_order_item_stock_picks TO anon;

GRANT ALL ON public.shop_order_item_stock_picks TO authenticated;

GRANT ALL ON public.shop_order_item_stock_picks TO service_role;