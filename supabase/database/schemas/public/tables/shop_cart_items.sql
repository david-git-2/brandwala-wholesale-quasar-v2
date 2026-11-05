CREATE TABLE public.shop_cart_items (
  id                                  bigint                   GENERATED ALWAYS AS IDENTITY NOT NULL,
  cart_id                             bigint                   NOT NULL,
  product_id                          bigint                   NOT NULL,
  global_stock_id                     bigint,
  global_stock_allocation_id          bigint,
  quantity                            integer                  NOT NULL,
  minimum_quantity                    integer                  DEFAULT 1 NOT NULL,
  unit_list_price_amount              numeric(12,4),
  unit_list_price_currency_id         bigint,
  unit_sell_price_amount              numeric(12,4),
  unit_sell_price_currency_id         bigint,
  unit_minimum_sell_price_amount      numeric(12,4),
  unit_minimum_sell_price_currency_id bigint,
  customer_sell_price_amount          numeric(12,4),
  customer_sell_price_currency_id     bigint,
  name                                text                     NOT NULL,
  image_url                           text,
  created_at                          timestamp with time zone DEFAULT now() NOT NULL,
  updated_at                          timestamp with time zone DEFAULT now() NOT NULL,
  listing_id                          bigint,
  grade_tag_id                        bigint
);

CREATE TRIGGER trg_shop_cart_items_updated_at
  BEFORE UPDATE ON public.shop_cart_items
  FOR EACH ROW
  EXECUTE FUNCTION public.set_shop_order_updated_at();

CREATE TRIGGER trg_sync_shop_cart_item_reservation
  AFTER INSERT OR DELETE OR UPDATE ON public.shop_cart_items
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_shop_cart_item_reservation();

CREATE POLICY shop_cart_items_customer_owner ON public.shop_cart_items
  USING ((EXISTS ( SELECT 1
   FROM public.shop_carts c
  WHERE ((c.id = shop_cart_items.cart_id) AND public.is_cart_owner(c.customer_group_id, c.tenant_id)))))
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.shop_carts c
  WHERE ((c.id = shop_cart_items.cart_id) AND public.is_cart_owner(c.customer_group_id, c.tenant_id)))));

CREATE POLICY shop_cart_items_staff_view ON public.shop_cart_items
  FOR SELECT
  USING ((EXISTS ( SELECT 1
   FROM public.shop_carts c
  WHERE ((c.id = shop_cart_items.cart_id) AND public.is_tenant_staff(c.tenant_id)))));

ALTER TABLE public.shop_cart_items
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.shop_cart_items
  ADD CONSTRAINT shop_cart_items_customer_sell_price_currency_id_fkey FOREIGN KEY (customer_sell_price_currency_id) REFERENCES public.global_currencies(id);

ALTER TABLE public.shop_cart_items
  ADD CONSTRAINT shop_cart_items_global_stock_id_fkey FOREIGN KEY (global_stock_id) REFERENCES public.global_stocks(id) ON DELETE SET NULL;

ALTER TABLE public.shop_cart_items
  ADD CONSTRAINT shop_cart_items_min_qty_positive CHECK (minimum_quantity > 0);

ALTER TABLE public.shop_cart_items
  ADD CONSTRAINT shop_cart_items_pkey PRIMARY KEY (id);

ALTER TABLE public.shop_cart_items
  ADD CONSTRAINT shop_cart_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE CASCADE;

ALTER TABLE public.shop_cart_items
  ADD CONSTRAINT shop_cart_items_qty_positive CHECK (quantity > 0);

ALTER TABLE public.shop_cart_items
  ADD CONSTRAINT shop_cart_items_unit_list_price_currency_id_fkey FOREIGN KEY (unit_list_price_currency_id) REFERENCES public.global_currencies(id);

ALTER TABLE public.shop_cart_items
  ADD CONSTRAINT shop_cart_items_unit_minimum_sell_price_currency_id_fkey FOREIGN KEY (unit_minimum_sell_price_currency_id) REFERENCES public.global_currencies(id);

ALTER TABLE public.shop_cart_items
  ADD CONSTRAINT shop_cart_items_unit_sell_price_currency_id_fkey FOREIGN KEY (unit_sell_price_currency_id) REFERENCES public.global_currencies(id);

ALTER TABLE public.shop_cart_items
  ADD CONSTRAINT shop_cart_items_cart_id_fkey FOREIGN KEY (cart_id) REFERENCES public.shop_carts(id) ON DELETE CASCADE;

ALTER TABLE public.shop_cart_items
  ADD CONSTRAINT shop_cart_items_listing_id_fkey FOREIGN KEY (listing_id) REFERENCES public.shop_product_listings(id) ON DELETE SET NULL;

ALTER TABLE public.shop_cart_items
  ADD CONSTRAINT shop_cart_items_grade_tag_id_fkey FOREIGN KEY (grade_tag_id) REFERENCES public.tags(id);

GRANT ALL ON public.shop_cart_items TO anon;

GRANT ALL ON public.shop_cart_items TO authenticated;

GRANT ALL ON public.shop_cart_items TO service_role;