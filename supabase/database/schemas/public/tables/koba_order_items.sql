CREATE TABLE public.koba_order_items (
  id                    bigint                   DEFAULT nextval('public.koba_order_items_id_seq'::regclass) NOT NULL,
  order_id              bigint                   NOT NULL,
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
  delivered_quantity    integer                  DEFAULT 0 NOT NULL,
  created_at            timestamp with time zone DEFAULT now() NOT NULL,
  updated_at            timestamp with time zone DEFAULT now() NOT NULL,
  confirmed_quantity    integer
);

CREATE INDEX koba_order_items_product_id_idx ON public.koba_order_items (product_id);

CREATE INDEX koba_order_items_order_id_idx ON public.koba_order_items (order_id);

CREATE TRIGGER trg_koba_order_items_updated_at
  BEFORE UPDATE ON public.koba_order_items
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY koba_order_items_delete ON public.koba_order_items
  FOR DELETE
  TO authenticated
  USING (public.koba_order_allowed(order_id));

CREATE POLICY koba_order_items_insert ON public.koba_order_items
  FOR INSERT
  TO authenticated
  WITH CHECK (public.koba_order_allowed(order_id));

CREATE POLICY koba_order_items_select ON public.koba_order_items
  FOR SELECT
  TO authenticated
  USING (public.koba_order_allowed(order_id));

CREATE POLICY koba_order_items_update ON public.koba_order_items
  FOR UPDATE
  TO authenticated
  USING (public.koba_order_allowed(order_id))
  WITH CHECK (public.koba_order_allowed(order_id));

COMMENT ON TABLE public.koba_order_items IS 'Immutable line-item snapshot of a koba order.';

ALTER SEQUENCE public.koba_order_items_id_seq OWNED BY public.koba_order_items.id;

ALTER TABLE public.koba_order_items
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.koba_order_items
  ADD CONSTRAINT koba_order_items_case_size_check CHECK (case_size >= 1);

ALTER TABLE public.koba_order_items
  ADD CONSTRAINT koba_order_items_delivered_quantity_check CHECK (delivered_quantity >= 0);

ALTER TABLE public.koba_order_items
  ADD CONSTRAINT koba_order_items_pkey PRIMARY KEY (id);

ALTER TABLE public.koba_order_items
  ADD CONSTRAINT koba_order_items_quantity_check CHECK (quantity > 0);

ALTER TABLE public.koba_order_items
  ADD CONSTRAINT koba_order_items_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.koba_orders(id) ON DELETE CASCADE;

GRANT ALL ON public.koba_order_items TO anon;

GRANT ALL ON public.koba_order_items TO authenticated;

GRANT ALL ON public.koba_order_items TO service_role;