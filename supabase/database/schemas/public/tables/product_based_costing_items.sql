CREATE TABLE public.product_based_costing_items (
  id                            bigint                   DEFAULT nextval('public.product_based_costing_items_id_seq'::regclass) NOT NULL,
  product_based_costing_file_id bigint,
  name                          text,
  image_url                     text,
  quantity                      numeric(12,3),
  barcode                       text,
  product_code                  text,
  web_link                      text,
  price_gbp                     numeric(12,2),
  product_weight                numeric(12,3),
  package_weight                numeric(12,3),
  offer_price                   numeric(12,2),
  created_at                    timestamp with time zone DEFAULT now() NOT NULL,
  updated_at                    timestamp with time zone DEFAULT now() NOT NULL,
  product_id                    bigint,
  note                          text,
  input_type                    text,
  vendor_code                   text,
  market_code                   text,
  brand                         text,
  assigned_shipment_id          bigint,
  vendor_id                     bigint,
  is_offer_price_manual         boolean                  DEFAULT false NOT NULL,
  confirmed_quantity            integer,
  sort_order                    integer                  DEFAULT 0 NOT NULL
);

CREATE INDEX product_based_costing_items_brand_idx ON public.product_based_costing_items (brand);

CREATE INDEX product_based_costing_items_file_sort_order_id_idx ON public.product_based_costing_items (product_based_costing_file_id, sort_order, id);

CREATE INDEX product_based_costing_items_market_code_idx ON public.product_based_costing_items (market_code);

CREATE INDEX product_based_costing_items_name_idx ON public.product_based_costing_items (name);

CREATE INDEX product_based_costing_items_note_idx ON public.product_based_costing_items USING gin (to_tsvector('simple'::regconfig, COALESCE(note, ''::text)));

CREATE INDEX product_based_costing_items_product_code_idx ON public.product_based_costing_items (product_code);

CREATE INDEX product_based_costing_items_vendor_code_idx ON public.product_based_costing_items (vendor_code);

CREATE INDEX product_based_costing_items_vendor_id_idx ON public.product_based_costing_items (vendor_id);

CREATE INDEX product_based_costing_items_assigned_shipment_id_idx ON public.product_based_costing_items (assigned_shipment_id);

CREATE INDEX product_based_costing_items_barcode_idx ON public.product_based_costing_items (barcode);

CREATE INDEX product_based_costing_items_file_id_idx ON public.product_based_costing_items (product_based_costing_file_id);

CREATE TRIGGER trg_pbc_items_auto_backlog
  AFTER INSERT OR DELETE OR UPDATE OF quantity, confirmed_quantity, product_id, price_gbp ON public.product_based_costing_items
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_fn_auto_upsert_pbc_backlog();

CREATE TRIGGER trg_product_based_costing_items_set_updated_at
  BEFORE UPDATE ON public.product_based_costing_items
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_product_based_costing_items_sync_vendor_reference_fields
  BEFORE INSERT OR UPDATE ON public.product_based_costing_items
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_vendor_reference_fields();

CREATE POLICY product_based_costing_items_delete ON public.product_based_costing_items
  FOR DELETE
  TO authenticated
  USING (public.can_manage_costing_item(product_based_costing_file_id));

CREATE POLICY product_based_costing_items_insert ON public.product_based_costing_items
  FOR INSERT
  TO authenticated
  WITH CHECK (public.can_manage_costing_item(product_based_costing_file_id));

CREATE POLICY product_based_costing_items_select ON public.product_based_costing_items
  FOR SELECT
  TO authenticated
  USING (public.can_view_costing_item(product_based_costing_file_id));

CREATE POLICY product_based_costing_items_update ON public.product_based_costing_items
  FOR UPDATE
  TO authenticated
  USING (public.can_manage_costing_item(product_based_costing_file_id))
  WITH CHECK (public.can_manage_costing_item(product_based_costing_file_id));

ALTER SEQUENCE public.product_based_costing_items_id_seq OWNED BY public.product_based_costing_items.id;

ALTER TABLE public.product_based_costing_items
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.product_based_costing_items
  ADD CONSTRAINT product_based_costing_items_assigned_shipment_id_fkey FOREIGN KEY (assigned_shipment_id) REFERENCES public.global_shipments(id) ON DELETE SET NULL;

ALTER TABLE public.product_based_costing_items
  ADD CONSTRAINT product_based_costing_items_input_type_check CHECK ((input_type = ANY (ARRAY['manual'::text, 'product_list'::text])) OR input_type IS NULL);

ALTER TABLE public.product_based_costing_items
  ADD CONSTRAINT product_based_costing_items_pkey PRIMARY KEY (id);

ALTER TABLE public.product_based_costing_items
  ADD CONSTRAINT product_based_costing_items_product_based_costing_file_id_fkey FOREIGN KEY (product_based_costing_file_id) REFERENCES public.product_based_costing_files(id)
    ON DELETE CASCADE;

ALTER TABLE public.product_based_costing_items
  ADD CONSTRAINT fk_product_based_costing_items_product FOREIGN KEY (product_id) REFERENCES public.products(id) ON UPDATE CASCADE ON DELETE SET NULL;

ALTER TABLE public.product_based_costing_items
  ADD CONSTRAINT product_based_costing_items_vendor_id_fkey FOREIGN KEY (vendor_id) REFERENCES public.vendors(id) ON UPDATE CASCADE ON DELETE SET NULL;

GRANT ALL ON public.product_based_costing_items TO anon;

GRANT ALL ON public.product_based_costing_items TO authenticated;

GRANT ALL ON public.product_based_costing_items TO service_role;