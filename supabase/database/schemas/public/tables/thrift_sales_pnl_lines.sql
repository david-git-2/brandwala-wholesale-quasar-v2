CREATE TABLE public.thrift_sales_pnl_lines (
  id                       bigint                   DEFAULT nextval('public.thrift_sales_pnl_lines_id_seq'::regclass) NOT NULL,
  tenant_id                bigint                   NOT NULL,
  invoice_id               bigint                   NOT NULL,
  invoice_item_id          bigint                   NOT NULL,
  stock_id                 bigint                   NOT NULL,
  inbound_shipment_id      bigint                   NOT NULL,
  outcome                  text                     NOT NULL,
  return_id                bigint,
  quantity                 integer                  DEFAULT 1 NOT NULL,
  sell_amount              numeric(12,2)            DEFAULT 0.00 NOT NULL,
  allocated_shop_delivery  numeric(12,2)            DEFAULT 0.00 NOT NULL,
  allocated_shop_cod_fee   numeric(12,2)            DEFAULT 0.00 NOT NULL,
  allocated_shop_packing   numeric(12,2)            DEFAULT 0.00 NOT NULL,
  allocated_return_courier numeric(12,2)            DEFAULT 0.00 NOT NULL,
  allocated_fees_total     numeric(12,2)            DEFAULT 0.00 NOT NULL,
  cogs_is_loss             boolean                  DEFAULT false NOT NULL,
  event_at                 timestamp with time zone DEFAULT now() NOT NULL,
  event_date               date                     DEFAULT ((now() AT TIME ZONE 'UTC'::text))::date NOT NULL,
  created_at               timestamp with time zone DEFAULT now() NOT NULL,
  updated_at               timestamp with time zone DEFAULT now() NOT NULL
);

CREATE INDEX idx_thrift_sales_pnl_lines_outcome ON public.thrift_sales_pnl_lines (tenant_id, outcome);

CREATE INDEX idx_thrift_sales_pnl_lines_tenant_event_date ON public.thrift_sales_pnl_lines (tenant_id, event_date DESC);

CREATE INDEX idx_thrift_sales_pnl_lines_shipment ON public.thrift_sales_pnl_lines (tenant_id, inbound_shipment_id, event_date DESC);

CREATE INDEX idx_thrift_sales_pnl_lines_invoice ON public.thrift_sales_pnl_lines (invoice_id);

CREATE TRIGGER trg_thrift_sales_pnl_lines_set_updated_at
  BEFORE UPDATE ON public.thrift_sales_pnl_lines
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY thrift_sales_pnl_lines_delete ON public.thrift_sales_pnl_lines
  FOR DELETE
  TO authenticated
  USING (public.membership_has_module_action(tenant_id, 'thrift_sales'::text, 'staff_mistake'::text));

CREATE POLICY thrift_sales_pnl_lines_insert ON public.thrift_sales_pnl_lines
  FOR INSERT
  TO authenticated
  WITH
    CHECK
    ((public.membership_has_module_action(tenant_id, 'thrift_sales'::text, 'create'::text) OR public.membership_has_module_action(tenant_id, 'thrift_sales'::text, 'return'::text)
    OR public.membership_has_module_action(tenant_id, 'thrift_sales'::text, 'edit'::text)));

CREATE POLICY thrift_sales_pnl_lines_select ON public.thrift_sales_pnl_lines
  FOR SELECT
  TO authenticated
  USING
    ((public.membership_has_module_action(tenant_id, 'thrift_sales'::text, 'view'::text) OR public.membership_has_module_action(tenant_id, 'thrift_reports'::text, 'view'::text)));

CREATE POLICY thrift_sales_pnl_lines_update ON public.thrift_sales_pnl_lines
  FOR UPDATE
  TO authenticated
  USING
    ((public.membership_has_module_action(tenant_id, 'thrift_sales'::text, 'return'::text) OR public.membership_has_module_action(tenant_id, 'thrift_sales'::text, 'edit'::text) OR
    public.membership_has_module_action(tenant_id, 'thrift_sales'::text, 'create'::text)))
  WITH
    CHECK
    ((public.membership_has_module_action(tenant_id, 'thrift_sales'::text, 'return'::text) OR public.membership_has_module_action(tenant_id, 'thrift_sales'::text, 'edit'::text) OR
    public.membership_has_module_action(tenant_id, 'thrift_sales'::text, 'create'::text)));

COMMENT ON TABLE public.thrift_sales_pnl_lines IS 'Per invoice-line economics fact for reports. COGS stays live via stock→inbound shipment.';

ALTER SEQUENCE public.thrift_sales_pnl_lines_id_seq OWNED BY public.thrift_sales_pnl_lines.id;

ALTER TABLE public.thrift_sales_pnl_lines
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.thrift_sales_pnl_lines
  ADD CONSTRAINT thrift_sales_pnl_lines_alloc_cod_check CHECK (allocated_shop_cod_fee >= 0::numeric);

ALTER TABLE public.thrift_sales_pnl_lines
  ADD CONSTRAINT thrift_sales_pnl_lines_alloc_delivery_check CHECK (allocated_shop_delivery >= 0::numeric);

ALTER TABLE public.thrift_sales_pnl_lines
  ADD CONSTRAINT thrift_sales_pnl_lines_alloc_packing_check CHECK (allocated_shop_packing >= 0::numeric);

ALTER TABLE public.thrift_sales_pnl_lines
  ADD CONSTRAINT thrift_sales_pnl_lines_alloc_return_check CHECK (allocated_return_courier >= 0::numeric);

ALTER TABLE public.thrift_sales_pnl_lines
  ADD CONSTRAINT thrift_sales_pnl_lines_fees_total_check
    CHECK (allocated_fees_total = (allocated_shop_delivery + allocated_shop_cod_fee + allocated_shop_packing + allocated_return_courier));

ALTER TABLE public.thrift_sales_pnl_lines
  ADD CONSTRAINT thrift_sales_pnl_lines_invoice_id_fkey FOREIGN KEY (invoice_id) REFERENCES public.thrift_sales_invoices(id) ON DELETE CASCADE;

ALTER TABLE public.thrift_sales_pnl_lines
  ADD CONSTRAINT thrift_sales_pnl_lines_invoice_item_id_fkey FOREIGN KEY (invoice_item_id) REFERENCES public.thrift_sales_invoice_items(id) ON DELETE CASCADE;

ALTER TABLE public.thrift_sales_pnl_lines
  ADD CONSTRAINT thrift_sales_pnl_lines_invoice_item_key UNIQUE (invoice_item_id);

ALTER TABLE public.thrift_sales_pnl_lines
  ADD CONSTRAINT thrift_sales_pnl_lines_outcome_check CHECK (outcome = ANY (ARRAY['DELIVERED'::text, 'RTO'::text, 'CUSTOMER_RETURN'::text]));

ALTER TABLE public.thrift_sales_pnl_lines
  ADD CONSTRAINT thrift_sales_pnl_lines_pkey PRIMARY KEY (id);

ALTER TABLE public.thrift_sales_pnl_lines
  ADD CONSTRAINT thrift_sales_pnl_lines_quantity_check CHECK (quantity > 0);

ALTER TABLE public.thrift_sales_pnl_lines
  ADD CONSTRAINT thrift_sales_pnl_lines_sell_amount_check CHECK (sell_amount >= 0::numeric);

ALTER TABLE public.thrift_sales_pnl_lines
  ADD CONSTRAINT thrift_sales_pnl_lines_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

ALTER TABLE public.thrift_sales_pnl_lines
  ADD CONSTRAINT thrift_sales_pnl_lines_return_id_fkey FOREIGN KEY (return_id) REFERENCES public.thrift_sales_returns(id) ON DELETE SET NULL;

ALTER TABLE public.thrift_sales_pnl_lines
  ADD CONSTRAINT thrift_sales_pnl_lines_inbound_shipment_id_fkey FOREIGN KEY (inbound_shipment_id) REFERENCES public.thrift_shipments(id) ON DELETE RESTRICT;

ALTER TABLE public.thrift_sales_pnl_lines
  ADD CONSTRAINT thrift_sales_pnl_lines_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES public.thrift_stocks(id) ON DELETE RESTRICT;

GRANT ALL ON public.thrift_sales_pnl_lines TO anon;

GRANT ALL ON public.thrift_sales_pnl_lines TO authenticated;

GRANT ALL ON public.thrift_sales_pnl_lines TO service_role;