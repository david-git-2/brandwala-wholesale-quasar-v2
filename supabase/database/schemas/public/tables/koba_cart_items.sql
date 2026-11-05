CREATE TABLE public.koba_cart_items (
  id                    bigint                   DEFAULT nextval('public.koba_cart_items_id_seq'::regclass) NOT NULL,
  cart_id               bigint                   NOT NULL,
  koba_product_id       uuid,
  product_id            text                     NOT NULL,
  product_code          text,
  barcode               text,
  name                  text                     NOT NULL,
  brand                 text,
  image_url             text,
  case_size             integer                  DEFAULT 1 NOT NULL,
  unit_price_gbp        numeric(12,2),
  commission            numeric(12,2),
  commission_percentage numeric(5,2),
  quantity              integer                  DEFAULT 1 NOT NULL,
  created_at            timestamp with time zone DEFAULT now() NOT NULL,
  updated_at            timestamp with time zone DEFAULT now() NOT NULL,
  custom_price_gbp      numeric(12,2)
);

CREATE INDEX koba_cart_items_cart_id_idx ON public.koba_cart_items (cart_id);

CREATE INDEX koba_cart_items_product_id_idx ON public.koba_cart_items (product_id);

CREATE TRIGGER trg_koba_cart_items_updated_at
  BEFORE UPDATE ON public.koba_cart_items
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY koba_cart_items_delete ON public.koba_cart_items
  FOR DELETE
  TO authenticated
  USING (public.koba_cart_allowed(cart_id));

CREATE POLICY koba_cart_items_insert ON public.koba_cart_items
  FOR INSERT
  TO authenticated
  WITH CHECK (public.koba_cart_allowed(cart_id));

CREATE POLICY koba_cart_items_select ON public.koba_cart_items
  FOR SELECT
  TO authenticated
  USING (public.koba_cart_allowed(cart_id));

CREATE POLICY koba_cart_items_update ON public.koba_cart_items
  FOR UPDATE
  TO authenticated
  USING (public.koba_cart_allowed(cart_id))
  WITH CHECK (public.koba_cart_allowed(cart_id));

COMMENT ON TABLE public.koba_cart_items IS 'Line items in a koba cart. Stores full product snapshot for cart resilience.';

ALTER SEQUENCE public.koba_cart_items_id_seq OWNED BY public.koba_cart_items.id;

ALTER TABLE public.koba_cart_items
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.koba_cart_items
  ADD CONSTRAINT koba_cart_items_case_size_check CHECK (case_size >= 1);

ALTER TABLE public.koba_cart_items
  ADD CONSTRAINT koba_cart_items_pkey PRIMARY KEY (id);

ALTER TABLE public.koba_cart_items
  ADD CONSTRAINT koba_cart_items_quantity_check CHECK (quantity > 0);

ALTER TABLE public.koba_cart_items
  ADD CONSTRAINT uq_koba_cart_items_product UNIQUE (cart_id, product_id);

ALTER TABLE public.koba_cart_items
  ADD CONSTRAINT koba_cart_items_cart_id_fkey FOREIGN KEY (cart_id) REFERENCES public.koba_carts(id) ON DELETE CASCADE;

ALTER TABLE public.koba_cart_items
  ADD CONSTRAINT koba_cart_items_koba_product_id_fkey FOREIGN KEY (koba_product_id) REFERENCES public.koba_products(id) ON DELETE SET NULL;

GRANT ALL ON public.koba_cart_items TO anon;

GRANT ALL ON public.koba_cart_items TO authenticated;

GRANT ALL ON public.koba_cart_items TO service_role;