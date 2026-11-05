CREATE TABLE public.shipment_items (
  id                     bigint                   DEFAULT nextval('public.shipment_items_id_seq'::regclass) NOT NULL,
  shipment_id            bigint                   NOT NULL,
  name                   text,
  quantity               integer                  DEFAULT 0 NOT NULL,
  barcode                text,
  product_code           text,
  product_id             bigint,
  image_url              text,
  product_weight         numeric(12,3),
  package_weight         numeric(12,3),
  price_gbp              numeric(12,2),
  created_at             timestamp with time zone DEFAULT now() NOT NULL,
  updated_at             timestamp with time zone DEFAULT now() NOT NULL,
  order_id               bigint,
  method                 text                     DEFAULT 'manual'::text NOT NULL,
  marker_tag             text,
  inspected              boolean                  DEFAULT false NOT NULL,
  receiving_splits       jsonb,
  cost_bdt               numeric(12,2),
  source_child_tenant_id bigint,
  source_type            text,
  source_id              bigint,
  sort_order             integer                  DEFAULT 0 NOT NULL
);

CREATE INDEX shipment_items_shipment_id_idx ON public.shipment_items (shipment_id);

CREATE UNIQUE INDEX shipment_items_shipment_product_unique ON public.shipment_items (shipment_id, product_id)
  WHERE product_id IS NOT NULL;

CREATE INDEX shipment_items_product_id_idx ON public.shipment_items (product_id);

CREATE INDEX shipment_items_order_id_idx ON public.shipment_items (order_id);

CREATE INDEX shipment_items_method_idx ON public.shipment_items (method);

CREATE INDEX shipment_items_marker_tag_idx ON public.shipment_items (marker_tag);

CREATE INDEX shipment_items_source_idx ON public.shipment_items (source_type, source_id);

CREATE TRIGGER trg_shipment_items_recalc_transaction_rate
  AFTER INSERT OR DELETE OR UPDATE OF price_gbp, quantity ON public.shipment_items
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_shipment_items_recalc_transaction_rate();

CREATE TRIGGER trg_shipment_items_set_updated_at
  BEFORE UPDATE ON public.shipment_items
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY shipment_items_delete ON public.shipment_items
  FOR DELETE
  TO authenticated
  USING (public.can_manage_shipment_by_id(shipment_id));

CREATE POLICY shipment_items_insert ON public.shipment_items
  FOR INSERT
  TO authenticated
  WITH CHECK (public.can_manage_shipment_by_id(shipment_id));

CREATE POLICY shipment_items_select ON public.shipment_items
  FOR SELECT
  TO authenticated
  USING (public.can_manage_shipment_by_id(shipment_id));

CREATE POLICY shipment_items_update ON public.shipment_items
  FOR UPDATE
  TO authenticated
  USING (public.can_manage_shipment_by_id(shipment_id))
  WITH CHECK (public.can_manage_shipment_by_id(shipment_id));

ALTER SEQUENCE public.shipment_items_id_seq OWNED BY public.shipment_items.id;

ALTER TABLE public.shipment_items
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.shipment_items
  ADD CONSTRAINT shipment_items_marker_tag_check CHECK ((marker_tag = ANY (ARRAY['price_reviewed'::text, 'issue'::text, 'done'::text])) OR marker_tag IS NULL);

ALTER TABLE public.shipment_items
  ADD CONSTRAINT shipment_items_method_check CHECK (method = ANY (ARRAY['order'::text, 'costing'::text, 'manual'::text]));

ALTER TABLE public.shipment_items
  ADD CONSTRAINT shipment_items_pkey PRIMARY KEY (id);

ALTER TABLE public.shipment_items
  ADD CONSTRAINT shipment_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE SET NULL;

ALTER TABLE public.shipment_items
  ADD CONSTRAINT shipment_items_quantity_check CHECK (quantity >= 0);

ALTER TABLE public.shipment_items
  ADD CONSTRAINT shipment_items_source_type_check CHECK (source_type = ANY (ARRAY['order_item'::text, 'costing_item'::text, 'manual'::text]));

ALTER TABLE public.shipment_items
  ADD CONSTRAINT shipment_items_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipments(id) ON DELETE CASCADE;

ALTER TABLE public.shipment_items
  ADD CONSTRAINT shipment_items_source_child_tenant_id_fkey FOREIGN KEY (source_child_tenant_id) REFERENCES public.tenants(id) ON DELETE SET NULL;

GRANT ALL ON public.shipment_items TO anon;

GRANT ALL ON public.shipment_items TO authenticated;

GRANT ALL ON public.shipment_items TO service_role;