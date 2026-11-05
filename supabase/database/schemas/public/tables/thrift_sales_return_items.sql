CREATE TABLE public.thrift_sales_return_items (
  id              bigint                   DEFAULT nextval('public.thrift_sales_return_items_id_seq'::regclass) NOT NULL,
  return_id       bigint                   NOT NULL,
  tenant_id       bigint                   NOT NULL,
  invoice_item_id bigint                   NOT NULL,
  stock_id        bigint                   NOT NULL,
  quantity        integer                  DEFAULT 1 NOT NULL,
  condition       text                     NOT NULL,
  refund_amount   numeric(12,2)            DEFAULT 0.00 NOT NULL,
  created_at      timestamp with time zone DEFAULT now() NOT NULL
);

CREATE INDEX idx_thrift_sales_return_items_stock ON public.thrift_sales_return_items (stock_id);

CREATE INDEX idx_thrift_sales_return_items_return ON public.thrift_sales_return_items (return_id);

CREATE POLICY thrift_sales_return_items_insert ON public.thrift_sales_return_items
  FOR INSERT
  TO authenticated
  WITH
    CHECK
    ((public.membership_has_module_action(tenant_id, 'thrift_sales'::text, 'return'::text) OR public.membership_has_module_action(tenant_id, 'thrift_sales'::text,
    'force_return'::text)));

CREATE POLICY thrift_sales_return_items_select ON public.thrift_sales_return_items
  FOR SELECT
  TO authenticated
  USING
    ((public.membership_has_module_action(tenant_id, 'thrift_sales'::text, 'view'::text) OR public.membership_has_module_action(tenant_id, 'thrift_reports'::text, 'view'::text)));

ALTER SEQUENCE public.thrift_sales_return_items_id_seq OWNED BY public.thrift_sales_return_items.id;

ALTER TABLE public.thrift_sales_return_items
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.thrift_sales_return_items
  ADD CONSTRAINT thrift_sales_return_items_condition_check CHECK (condition = ANY (ARRAY['SELLABLE'::text, 'DAMAGED'::text]));

ALTER TABLE public.thrift_sales_return_items
  ADD CONSTRAINT thrift_sales_return_items_invoice_item_id_fkey FOREIGN KEY (invoice_item_id) REFERENCES public.thrift_sales_invoice_items(id) ON DELETE RESTRICT;

ALTER TABLE public.thrift_sales_return_items
  ADD CONSTRAINT thrift_sales_return_items_invoice_item_key UNIQUE (invoice_item_id);

ALTER TABLE public.thrift_sales_return_items
  ADD CONSTRAINT thrift_sales_return_items_pkey PRIMARY KEY (id);

ALTER TABLE public.thrift_sales_return_items
  ADD CONSTRAINT thrift_sales_return_items_quantity_check CHECK (quantity > 0);

ALTER TABLE public.thrift_sales_return_items
  ADD CONSTRAINT thrift_sales_return_items_refund_amount_check CHECK (refund_amount >= 0::numeric);

ALTER TABLE public.thrift_sales_return_items
  ADD CONSTRAINT thrift_sales_return_items_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

ALTER TABLE public.thrift_sales_return_items
  ADD CONSTRAINT thrift_sales_return_items_return_id_fkey FOREIGN KEY (return_id) REFERENCES public.thrift_sales_returns(id) ON DELETE CASCADE;

ALTER TABLE public.thrift_sales_return_items
  ADD CONSTRAINT thrift_sales_return_items_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES public.thrift_stocks(id) ON DELETE RESTRICT;

GRANT ALL ON public.thrift_sales_return_items TO anon;

GRANT ALL ON public.thrift_sales_return_items TO authenticated;

GRANT ALL ON public.thrift_sales_return_items TO service_role;