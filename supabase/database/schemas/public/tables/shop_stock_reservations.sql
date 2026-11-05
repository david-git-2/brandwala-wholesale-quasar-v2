CREATE TABLE public.shop_stock_reservations (
  cart_item_id               bigint                   NOT NULL,
  global_stock_allocation_id bigint,
  quantity                   integer                  NOT NULL,
  created_at                 timestamp with time zone DEFAULT now() NOT NULL,
  updated_at                 timestamp with time zone DEFAULT now() NOT NULL,
  global_stock_id            bigint
);

CREATE TRIGGER trg_shop_stock_reservations_updated_at
  BEFORE UPDATE ON public.shop_stock_reservations
  FOR EACH ROW
  EXECUTE FUNCTION public.set_shop_order_updated_at();

CREATE POLICY shop_stock_reservations_customer_owner ON public.shop_stock_reservations
  USING ((EXISTS ( SELECT 1
   FROM (public.shop_cart_items ci
     JOIN public.shop_carts c ON ((c.id = ci.cart_id)))
  WHERE ((ci.id = shop_stock_reservations.cart_item_id) AND public.is_cart_owner(c.customer_group_id, c.tenant_id)))))
  WITH CHECK ((EXISTS ( SELECT 1
   FROM (public.shop_cart_items ci
     JOIN public.shop_carts c ON ((c.id = ci.cart_id)))
  WHERE ((ci.id = shop_stock_reservations.cart_item_id) AND public.is_cart_owner(c.customer_group_id, c.tenant_id)))));

CREATE POLICY shop_stock_reservations_staff_view ON public.shop_stock_reservations
  FOR SELECT
  USING ((EXISTS ( SELECT 1
   FROM (public.shop_cart_items ci
     JOIN public.shop_carts c ON ((c.id = ci.cart_id)))
  WHERE ((ci.id = shop_stock_reservations.cart_item_id) AND public.is_tenant_staff(c.tenant_id)))));

ALTER TABLE public.shop_stock_reservations
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.shop_stock_reservations
  ADD CONSTRAINT shop_stock_reservations_cart_item_id_fkey FOREIGN KEY (cart_item_id) REFERENCES public.shop_cart_items(id) ON DELETE CASCADE;

ALTER TABLE public.shop_stock_reservations
  ADD CONSTRAINT shop_stock_reservations_global_stock_id_fkey FOREIGN KEY (global_stock_id) REFERENCES public.global_stocks(id) ON DELETE CASCADE;

ALTER TABLE public.shop_stock_reservations
  ADD CONSTRAINT shop_stock_reservations_pkey PRIMARY KEY (cart_item_id);

ALTER TABLE public.shop_stock_reservations
  ADD CONSTRAINT shop_stock_reservations_qty_non_negative CHECK (quantity >= 0);

GRANT ALL ON public.shop_stock_reservations TO anon;

GRANT ALL ON public.shop_stock_reservations TO authenticated;

GRANT ALL ON public.shop_stock_reservations TO service_role;