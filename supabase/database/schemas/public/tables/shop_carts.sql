CREATE TABLE public.shop_carts (
  id                          bigint                   GENERATED ALWAYS AS IDENTITY NOT NULL,
  tenant_id                   bigint                   NOT NULL,
  shop_id                     bigint                   NOT NULL,
  customer_group_id           bigint                   NOT NULL,
  status                      public.shop_cart_status  DEFAULT 'active'::public.shop_cart_status NOT NULL,
  created_at                  timestamp with time zone DEFAULT now() NOT NULL,
  updated_at                  timestamp with time zone DEFAULT now() NOT NULL,
  cod_charge_amount           numeric(12,2)            DEFAULT 0 NOT NULL,
  delivery_charge_amount      numeric(12,2)            DEFAULT 0 NOT NULL,
  print_charge_amount         numeric(12,2)            DEFAULT 0 NOT NULL,
  packing_charge_amount       numeric(12,2)            DEFAULT 0 NOT NULL,
  discount_amount             numeric(12,2)            DEFAULT 0 NOT NULL,
  is_prepaid                  boolean                  DEFAULT false NOT NULL,
  delivery_instructions       text,
  deduct_charges_from_margin  boolean                  DEFAULT false NOT NULL,
  deduct_print_from_margin    boolean                  DEFAULT false NOT NULL,
  deduct_packing_from_margin  boolean                  DEFAULT false NOT NULL,
  deduct_cod_from_margin      boolean                  DEFAULT false NOT NULL,
  deduct_delivery_from_margin boolean                  DEFAULT false NOT NULL,
  can_see_buy_price_snapshot  boolean                  DEFAULT false NOT NULL,
  can_see_sell_price_snapshot boolean                  DEFAULT false NOT NULL
);

CREATE UNIQUE INDEX shop_carts_active_unique_idx ON public.shop_carts (tenant_id, shop_id, customer_group_id)
  WHERE status = 'active'::public.shop_cart_status;

CREATE TRIGGER trg_shop_carts_updated_at
  BEFORE UPDATE ON public.shop_carts
  FOR EACH ROW
  EXECUTE FUNCTION public.set_shop_order_updated_at();

CREATE POLICY shop_carts_customer_owner ON public.shop_carts
  USING (public.is_cart_owner(customer_group_id, tenant_id))
  WITH CHECK (public.is_cart_owner(customer_group_id, tenant_id));

CREATE POLICY shop_carts_staff_view ON public.shop_carts
  FOR SELECT
  USING (public.is_tenant_staff(tenant_id));

ALTER TABLE public.shop_carts
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.shop_carts
  ADD CONSTRAINT shop_carts_customer_group_id_fkey FOREIGN KEY (customer_group_id) REFERENCES public.customer_groups(id) ON DELETE CASCADE;

ALTER TABLE public.shop_carts
  ADD CONSTRAINT shop_carts_pkey PRIMARY KEY (id);

ALTER TABLE public.shop_carts
  ADD CONSTRAINT shop_carts_shop_id_fkey FOREIGN KEY (shop_id) REFERENCES public.shops(id) ON DELETE CASCADE;

ALTER TABLE public.shop_carts
  ADD CONSTRAINT shop_carts_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.shop_carts TO anon;

GRANT ALL ON public.shop_carts TO authenticated;

GRANT ALL ON public.shop_carts TO service_role;