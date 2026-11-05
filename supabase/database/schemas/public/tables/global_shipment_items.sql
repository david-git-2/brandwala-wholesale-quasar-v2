CREATE TABLE public.global_shipment_items (
  id                     bigint                                 DEFAULT nextval('public.global_shipment_items_id_seq'::regclass) NOT NULL,
  shipment_id            bigint                                 NOT NULL,
  product_id             bigint,
  name                   text                                   NOT NULL,
  ordered_quantity       integer                                NOT NULL,
  image_url              text,
  add_method             public.global_shipment_item_add_method DEFAULT 'manual'::public.global_shipment_item_add_method NOT NULL,
  purchase_price         numeric                                DEFAULT 0.0 NOT NULL,
  product_weight         numeric                                DEFAULT 0.0 NOT NULL,
  package_weight         numeric                                DEFAULT 0.0 NOT NULL,
  barcode                text,
  product_code           text,
  source_child_tenant_id bigint,
  source_type            text,
  source_id              bigint,
  created_at             timestamp with time zone               DEFAULT now() NOT NULL,
  updated_at             timestamp with time zone               DEFAULT now() NOT NULL,
  vendor_id              bigint,
  sort_order             integer                                DEFAULT 0 NOT NULL,
  landed_cost_bdt        numeric,
  received_quantity      integer,
  section_id             bigint
);

CREATE INDEX global_shipment_items_section_idx ON public.global_shipment_items (section_id);

CREATE INDEX global_shipment_items_shipment_idx ON public.global_shipment_items (shipment_id);

CREATE INDEX global_shipment_items_product_idx ON public.global_shipment_items (product_id);

CREATE TRIGGER trg_global_shipment_items_guard_landed_cost
  BEFORE INSERT OR UPDATE ON public.global_shipment_items
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_global_shipment_items_guard_landed_cost();

CREATE TRIGGER trg_global_shipment_items_reactive_cost
  AFTER UPDATE OF purchase_price ON public.global_shipment_items
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_reactive_adjust_child_listing_cost();

CREATE TRIGGER trg_global_shipment_items_restamp_landed_cost
  AFTER UPDATE OF product_weight, package_weight, purchase_price, ordered_quantity ON public.global_shipment_items
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_global_shipment_items_restamp_landed_cost();

CREATE TRIGGER trg_global_shipment_items_sync_catalog_weights
  AFTER INSERT OR UPDATE OF product_weight, package_weight, product_id ON public.global_shipment_items
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_sync_catalog_weights_from_global_shipment_item();

CREATE TRIGGER trg_global_shipment_items_updated_at
  BEFORE UPDATE ON public.global_shipment_items
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY global_shipment_items_all ON public.global_shipment_items
  TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM public.global_shipments gs
  WHERE ((gs.id = global_shipment_items.shipment_id) AND public.user_can_manage_parent_tenant(gs.parent_tenant_id)))))
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.global_shipments gs
  WHERE ((gs.id = global_shipment_items.shipment_id) AND public.user_can_manage_parent_tenant(gs.parent_tenant_id)))));

CREATE POLICY global_shipment_items_select ON public.global_shipment_items
  FOR SELECT
  TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM public.global_shipments gs
  WHERE (gs.id = global_shipment_items.shipment_id))));

COMMENT ON COLUMN public.global_shipment_items.landed_cost_bdt IS 'Authoritative per-unit landed BDT. Written only by finalize/revision stamp RPCs. Null while draft.';

ALTER SEQUENCE public.global_shipment_items_id_seq OWNED BY public.global_shipment_items.id;

ALTER TABLE public.global_shipment_items
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.global_shipment_items
  ADD CONSTRAINT global_shipment_items_name_not_blank CHECK (length(TRIM(BOTH FROM name)) > 0);

ALTER TABLE public.global_shipment_items
  ADD CONSTRAINT global_shipment_items_ordered_quantity_check CHECK (ordered_quantity >= 0);

ALTER TABLE public.global_shipment_items
  ADD CONSTRAINT global_shipment_items_pkey PRIMARY KEY (id);

ALTER TABLE public.global_shipment_items
  ADD CONSTRAINT global_shipment_items_received_quantity_check CHECK (received_quantity IS NULL OR received_quantity >= 0);

ALTER TABLE public.global_shipment_items
  ADD CONSTRAINT global_shipment_items_section_id_fkey FOREIGN KEY (section_id) REFERENCES public.global_shipment_sections(id) ON DELETE SET NULL;

ALTER TABLE public.global_shipment_items
  ADD CONSTRAINT global_shipment_items_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.global_shipments(id) ON DELETE CASCADE;

ALTER TABLE public.global_shipment_items
  ADD CONSTRAINT global_shipment_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE SET NULL;

ALTER TABLE public.global_shipment_items
  ADD CONSTRAINT global_shipment_items_source_child_tenant_id_fkey FOREIGN KEY (source_child_tenant_id) REFERENCES public.tenants(id) ON DELETE SET NULL;

ALTER TABLE public.global_shipment_items
  ADD CONSTRAINT global_shipment_items_vendor_id_fkey FOREIGN KEY (vendor_id) REFERENCES public.vendors(id) ON DELETE SET NULL;

GRANT ALL ON public.global_shipment_items TO anon;

GRANT ALL ON public.global_shipment_items TO authenticated;

GRANT ALL ON public.global_shipment_items TO service_role;