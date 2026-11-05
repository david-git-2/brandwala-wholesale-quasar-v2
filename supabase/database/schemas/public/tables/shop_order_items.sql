CREATE TABLE public.shop_order_items (
  id                                  bigint                   GENERATED ALWAYS AS IDENTITY NOT NULL,
  order_id                            bigint                   NOT NULL,
  product_id                          bigint,
  global_stock_id                     bigint,
  global_stock_allocation_id          bigint,
  name                                text                     NOT NULL,
  image_url                           text,
  quantity                            integer                  NOT NULL,
  unit_list_price_amount              numeric(12,4),
  unit_list_price_currency_id         bigint,
  unit_sell_price_amount              numeric(12,4),
  unit_sell_price_currency_id         bigint,
  unit_minimum_sell_price_amount      numeric(12,4),
  unit_minimum_sell_price_currency_id bigint,
  customer_sell_price_amount          numeric(12,4),
  customer_sell_price_currency_id     bigint,
  customer_offer_amount               numeric(12,4),
  customer_offer_currency_id          bigint,
  staff_offer_amount                  numeric(12,4),
  staff_offer_currency_id             bigint,
  final_price_amount                  numeric(12,4),
  final_price_currency_id             bigint,
  returned_quantity                   integer                  DEFAULT 0 NOT NULL,
  procurement_pulled                  boolean                  DEFAULT false NOT NULL,
  created_at                          timestamp with time zone DEFAULT now() NOT NULL,
  updated_at                          timestamp with time zone DEFAULT now() NOT NULL,
  confirmed_quantity                  integer,
  weight_kg                           numeric(12,4),
  cost_price_amount                   numeric(12,4),
  cost_price_currency_id              bigint,
  customer_decision_status            text                     DEFAULT 'pending'::text,
  customer_decision_at                timestamp with time zone,
  negotiation_status                  text                     DEFAULT 'pending'::text,
  staff_offer_at                      timestamp with time zone,
  customer_counter_at                 timestamp with time zone,
  final_offer_at                      timestamp with time zone,
  is_first_offer_manual               boolean                  DEFAULT false NOT NULL,
  is_final_offer_manual               boolean                  DEFAULT false NOT NULL,
  listing_id                          bigint,
  grade_tag_id                        bigint,
  is_fulfillment_unavailable          boolean                  DEFAULT false NOT NULL,
  unavailable_reason                  text,
  unavailable_at                      timestamp with time zone,
  unavailable_by_email                text,
  shortfall_quantity                  integer                  DEFAULT 0 NOT NULL,
  is_gift                             boolean                  DEFAULT false NOT NULL,
  gift_source                         text,
  gift_cost_amount                    numeric(12,4)            DEFAULT 0 NOT NULL,
  gift_cost_charged_to                text,
  shop_customer_stock_id              bigint,
  gift_added_by                       text
);

CREATE TRIGGER trg_shop_order_items_updated_at
  BEFORE UPDATE ON public.shop_order_items
  FOR EACH ROW
  EXECUTE FUNCTION public.set_shop_order_updated_at();

CREATE POLICY shop_order_items_customer_owner ON public.shop_order_items
  USING ((EXISTS ( SELECT 1
   FROM public.shop_orders o
  WHERE ((o.id = shop_order_items.order_id) AND public.is_cart_owner(o.customer_group_id, o.tenant_id)))))
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.shop_orders o
  WHERE ((o.id = shop_order_items.order_id) AND public.is_cart_owner(o.customer_group_id, o.tenant_id)))));

CREATE POLICY shop_order_items_staff_all ON public.shop_order_items
  USING ((EXISTS ( SELECT 1
   FROM public.shop_orders o
  WHERE ((o.id = shop_order_items.order_id) AND public.is_tenant_staff(o.tenant_id)))))
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.shop_orders o
  WHERE ((o.id = shop_order_items.order_id) AND public.is_tenant_staff(o.tenant_id)))));

ALTER TABLE public.shop_order_items
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.shop_order_items
  ADD CONSTRAINT shop_order_items_cost_price_currency_id_fkey FOREIGN KEY (cost_price_currency_id) REFERENCES public.global_currencies(id);

ALTER TABLE public.shop_order_items
  ADD CONSTRAINT shop_order_items_customer_offer_currency_id_fkey FOREIGN KEY (customer_offer_currency_id) REFERENCES public.global_currencies(id);

ALTER TABLE public.shop_order_items
  ADD CONSTRAINT shop_order_items_customer_sell_price_currency_id_fkey FOREIGN KEY (customer_sell_price_currency_id) REFERENCES public.global_currencies(id);

ALTER TABLE public.shop_order_items
  ADD CONSTRAINT shop_order_items_final_price_currency_id_fkey FOREIGN KEY (final_price_currency_id) REFERENCES public.global_currencies(id);

ALTER TABLE public.shop_order_items
  ADD CONSTRAINT shop_order_items_gift_added_by_check CHECK (gift_added_by IS NULL OR (gift_added_by = ANY (ARRAY['manual'::text, 'auto'::text])));

ALTER TABLE public.shop_order_items
  ADD CONSTRAINT shop_order_items_gift_charged_to_check CHECK (gift_cost_charged_to IS NULL OR (gift_cost_charged_to = ANY (ARRAY['reseller'::text, 'tenant'::text])));

ALTER TABLE public.shop_order_items
  ADD CONSTRAINT shop_order_items_gift_source_check CHECK (gift_source IS NULL OR (gift_source = ANY (ARRAY['stock'::text, 'customer_stock'::text])));

ALTER TABLE public.shop_order_items
  ADD CONSTRAINT shop_order_items_global_stock_id_fkey FOREIGN KEY (global_stock_id) REFERENCES public.global_stocks(id) ON DELETE SET NULL;

ALTER TABLE public.shop_order_items
  ADD CONSTRAINT shop_order_items_pkey PRIMARY KEY (id);

ALTER TABLE public.shop_order_items
  ADD CONSTRAINT shop_order_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE CASCADE;

ALTER TABLE public.shop_order_items
  ADD CONSTRAINT shop_order_items_product_id_gift_check CHECK (product_id IS NOT NULL OR is_gift = true AND gift_source = 'customer_stock'::text);

ALTER TABLE public.shop_order_items
  ADD CONSTRAINT shop_order_items_qty_non_negative CHECK (quantity >= 0);

ALTER TABLE public.shop_order_items
  ADD CONSTRAINT shop_order_items_shop_customer_stock_id_fkey FOREIGN KEY (shop_customer_stock_id) REFERENCES public.shop_customer_stocks(id) ON DELETE SET NULL;

ALTER TABLE public.shop_order_items
  ADD CONSTRAINT shop_order_items_shortfall_non_negative CHECK (shortfall_quantity >= 0);

ALTER TABLE public.shop_order_items
  ADD CONSTRAINT shop_order_items_staff_offer_currency_id_fkey FOREIGN KEY (staff_offer_currency_id) REFERENCES public.global_currencies(id);

ALTER TABLE public.shop_order_items
  ADD CONSTRAINT shop_order_items_unit_list_price_currency_id_fkey FOREIGN KEY (unit_list_price_currency_id) REFERENCES public.global_currencies(id);

ALTER TABLE public.shop_order_items
  ADD CONSTRAINT shop_order_items_unit_minimum_sell_price_currency_id_fkey FOREIGN KEY (unit_minimum_sell_price_currency_id) REFERENCES public.global_currencies(id);

ALTER TABLE public.shop_order_items
  ADD CONSTRAINT shop_order_items_unit_sell_price_currency_id_fkey FOREIGN KEY (unit_sell_price_currency_id) REFERENCES public.global_currencies(id);

ALTER TABLE public.shop_order_items
  ADD CONSTRAINT shop_order_items_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.shop_orders(id) ON DELETE CASCADE;

ALTER TABLE public.shop_order_items
  ADD CONSTRAINT shop_order_items_listing_id_fkey FOREIGN KEY (listing_id) REFERENCES public.shop_product_listings(id) ON DELETE SET NULL;

ALTER TABLE public.shop_order_items
  ADD CONSTRAINT shop_order_items_grade_tag_id_fkey FOREIGN KEY (grade_tag_id) REFERENCES public.tags(id);

GRANT ALL ON public.shop_order_items TO anon;

GRANT ALL ON public.shop_order_items TO authenticated;

GRANT ALL ON public.shop_order_items TO service_role;