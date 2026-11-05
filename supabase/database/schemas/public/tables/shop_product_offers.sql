CREATE TABLE public.shop_product_offers (
  id               bigint                   GENERATED ALWAYS AS IDENTITY NOT NULL,
  shop_id          bigint                   NOT NULL,
  product_id       bigint                   NOT NULL,
  condition_bucket character varying(50)    DEFAULT 'normal'::character varying NOT NULL,
  price            numeric(12,2)            NOT NULL,
  is_active        boolean                  DEFAULT true NOT NULL,
  created_at       timestamp with time zone DEFAULT now() NOT NULL,
  updated_at       timestamp with time zone DEFAULT now() NOT NULL
);

CREATE POLICY shop_product_offers_all_staff ON public.shop_product_offers
  USING ((auth.role() = 'authenticated'::text));

CREATE POLICY shop_product_offers_select ON public.shop_product_offers
  FOR SELECT
  USING (true);

ALTER TABLE public.shop_product_offers
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.shop_product_offers
  ADD CONSTRAINT shop_product_offers_condition_bucket_check
    CHECK (condition_bucket::text = ANY (ARRAY['normal'::character varying::text, 'open_box'::character varying::text, 'damaged'::character varying::text]));

ALTER TABLE public.shop_product_offers
  ADD CONSTRAINT shop_product_offers_pkey PRIMARY KEY (id);

ALTER TABLE public.shop_product_offers
  ADD CONSTRAINT shop_product_offers_price_check CHECK (price >= 0::numeric);

ALTER TABLE public.shop_product_offers
  ADD CONSTRAINT shop_product_offers_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE CASCADE;

ALTER TABLE public.shop_product_offers
  ADD CONSTRAINT shop_product_offers_shop_prod_cond_key UNIQUE (shop_id, product_id, condition_bucket);

ALTER TABLE public.shop_product_offers
  ADD CONSTRAINT shop_product_offers_shop_id_fkey FOREIGN KEY (shop_id) REFERENCES public.shops(id) ON DELETE CASCADE;

GRANT ALL ON public.shop_product_offers TO anon;

GRANT ALL ON public.shop_product_offers TO authenticated;

GRANT ALL ON public.shop_product_offers TO service_role;