CREATE TABLE public.shipments (
  id                      bigint                   DEFAULT nextval('public.shipments_id_seq'::regclass) NOT NULL,
  tenant_id               bigint                   NOT NULL,
  name                    text                     NOT NULL,
  product_conversion_rate numeric(12,4),
  cargo_conversion_rate   numeric(12,4),
  cargo_rate              numeric(12,4),
  received_weight         numeric(12,3),
  created_at              timestamp with time zone DEFAULT now() NOT NULL,
  updated_at              timestamp with time zone DEFAULT now() NOT NULL,
  status                  text                     DEFAULT 'Draft'::text NOT NULL,
  inventory_added         boolean                  DEFAULT false NOT NULL,
  market_code             text,
  tenant_shipment_id      bigint                   NOT NULL,
  transaction_rate        numeric(12,4),
  shipment_type           text                     DEFAULT 'international'::text NOT NULL
);

CREATE INDEX shipments_status_idx ON public.shipments (status);

CREATE UNIQUE INDEX shipments_tenant_id_tenant_shipment_id_uidx ON public.shipments (tenant_id, tenant_shipment_id);

CREATE INDEX shipments_tenant_id_idx ON public.shipments (tenant_id);

CREATE INDEX shipments_tenant_shipment_id_idx ON public.shipments (tenant_shipment_id);

CREATE INDEX shipments_market_code_idx ON public.shipments (market_code);

CREATE TRIGGER trg_assign_tenant_shipment_id
  BEFORE INSERT OR UPDATE ON public.shipments
  FOR EACH ROW
  EXECUTE FUNCTION public.assign_tenant_shipment_id();

CREATE TRIGGER trg_shipments_recalc_transaction_rate
  AFTER UPDATE OF product_conversion_rate, cargo_conversion_rate, cargo_rate, received_weight, shipment_type ON public.shipments
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_shipments_recalc_transaction_rate();

CREATE TRIGGER trg_shipments_set_updated_at
  BEFORE UPDATE ON public.shipments
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_shipments_sync_vendor_reference_fields
  BEFORE INSERT OR UPDATE ON public.shipments
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_vendor_reference_fields();

CREATE POLICY shipments_delete ON public.shipments
  FOR DELETE
  TO authenticated
  USING (public.can_manage_shipment(tenant_id));

CREATE POLICY shipments_insert ON public.shipments
  FOR INSERT
  TO authenticated
  WITH CHECK (public.can_manage_shipment(tenant_id));

CREATE POLICY shipments_select ON public.shipments
  FOR SELECT
  TO authenticated
  USING (public.can_manage_shipment(tenant_id));

CREATE POLICY shipments_update ON public.shipments
  FOR UPDATE
  TO authenticated
  USING (public.can_manage_shipment(tenant_id))
  WITH CHECK (public.can_manage_shipment(tenant_id));

ALTER SEQUENCE public.shipments_id_seq OWNED BY public.shipments.id;

ALTER TABLE public.shipments
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.shipments
  ADD CONSTRAINT shipments_market_code_fkey FOREIGN KEY (market_code) REFERENCES public.markets(code) ON UPDATE CASCADE ON DELETE SET NULL;

ALTER TABLE public.shipments
  ADD CONSTRAINT shipments_name_not_blank CHECK (length(TRIM(BOTH FROM name)) > 0);

ALTER TABLE public.shipments
  ADD CONSTRAINT shipments_pkey PRIMARY KEY (id);

ALTER TABLE public.shipments
  ADD CONSTRAINT shipments_shipment_type_check CHECK (shipment_type = ANY (ARRAY['local'::text, 'international'::text]));

ALTER TABLE public.shipments
  ADD CONSTRAINT shipments_status_check
    CHECK
    (status = ANY (ARRAY['Draft'::text, 'Order Placed'::text, 'Proforma Generated'::text, 'Payment Done'::text, 'Delivery Date Received'::text,
    'Uk Warehouse Delivery Received'::text,
    'Air Shipment Date Set'::text, 'Airport Arrival'::text, 'Airport Released'::text, 'Warehouse Received'::text, 'Added to Inventory'::text]));

ALTER TABLE public.shipments
  ADD CONSTRAINT shipments_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.shipments TO anon;

GRANT ALL ON public.shipments TO authenticated;

GRANT ALL ON public.shipments TO service_role;