CREATE TABLE public.thrift_sales_returns (
  id                    bigint                   DEFAULT nextval('public.thrift_sales_returns_id_seq'::regclass) NOT NULL,
  tenant_id             bigint                   NOT NULL,
  invoice_id            bigint                   NOT NULL,
  return_number         text                     NOT NULL,
  status                text                     DEFAULT 'COMPLETED'::text NOT NULL,
  refund_amount         numeric(12,2)            DEFAULT 0.00 NOT NULL,
  return_courier_amount numeric(12,2)            DEFAULT 0.00 NOT NULL,
  notes                 text,
  created_by            text                     DEFAULT ''::text NOT NULL,
  created_at            timestamp with time zone DEFAULT now() NOT NULL,
  updated_at            timestamp with time zone DEFAULT now() NOT NULL
);

CREATE INDEX idx_thrift_sales_returns_invoice ON public.thrift_sales_returns (invoice_id);

CREATE INDEX idx_thrift_sales_returns_tenant_created ON public.thrift_sales_returns (tenant_id, created_at DESC);

CREATE TRIGGER trg_thrift_sales_returns_set_updated_at
  BEFORE UPDATE ON public.thrift_sales_returns
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY thrift_sales_returns_insert ON public.thrift_sales_returns
  FOR INSERT
  TO authenticated
  WITH
    CHECK
    ((public.membership_has_module_action(tenant_id, 'thrift_sales'::text, 'return'::text) OR public.membership_has_module_action(tenant_id, 'thrift_sales'::text,
    'force_return'::text)));

CREATE POLICY thrift_sales_returns_select ON public.thrift_sales_returns
  FOR SELECT
  TO authenticated
  USING
    ((public.membership_has_module_action(tenant_id, 'thrift_sales'::text, 'view'::text) OR public.membership_has_module_action(tenant_id, 'thrift_reports'::text, 'view'::text)));

CREATE POLICY thrift_sales_returns_update ON public.thrift_sales_returns
  FOR UPDATE
  TO authenticated
  USING
    ((public.membership_has_module_action(tenant_id, 'thrift_sales'::text, 'return'::text) OR public.membership_has_module_action(tenant_id, 'thrift_sales'::text,
    'force_return'::text)))
  WITH
    CHECK
    ((public.membership_has_module_action(tenant_id, 'thrift_sales'::text, 'return'::text) OR public.membership_has_module_action(tenant_id, 'thrift_sales'::text,
    'force_return'::text)));

COMMENT ON TABLE public.thrift_sales_returns IS 'Post-pay / post-delivery returns (partial or full). Not used for RTO no-pickup.';

ALTER SEQUENCE public.thrift_sales_returns_id_seq OWNED BY public.thrift_sales_returns.id;

ALTER TABLE public.thrift_sales_returns
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.thrift_sales_returns
  ADD CONSTRAINT thrift_sales_returns_courier_amount_check CHECK (return_courier_amount >= 0::numeric);

ALTER TABLE public.thrift_sales_returns
  ADD CONSTRAINT thrift_sales_returns_invoice_id_fkey FOREIGN KEY (invoice_id) REFERENCES public.thrift_sales_invoices(id) ON DELETE CASCADE;

ALTER TABLE public.thrift_sales_returns
  ADD CONSTRAINT thrift_sales_returns_pkey PRIMARY KEY (id);

ALTER TABLE public.thrift_sales_returns
  ADD CONSTRAINT thrift_sales_returns_refund_amount_check CHECK (refund_amount >= 0::numeric);

ALTER TABLE public.thrift_sales_returns
  ADD CONSTRAINT thrift_sales_returns_status_check CHECK (status = 'COMPLETED'::text);

ALTER TABLE public.thrift_sales_returns
  ADD CONSTRAINT thrift_sales_returns_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

ALTER TABLE public.thrift_sales_returns
  ADD CONSTRAINT thrift_sales_returns_tenant_number_key UNIQUE (tenant_id, return_number);

GRANT ALL ON public.thrift_sales_returns TO anon;

GRANT ALL ON public.thrift_sales_returns TO authenticated;

GRANT ALL ON public.thrift_sales_returns TO service_role;