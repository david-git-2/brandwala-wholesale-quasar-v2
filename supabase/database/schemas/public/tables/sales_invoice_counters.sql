CREATE TABLE public.sales_invoice_counters (
  tenant_id    bigint                     NOT NULL,
  invoice_type public.global_invoice_type NOT NULL,
  date_key     text                       NOT NULL,
  last_value   bigint                     DEFAULT 0 NOT NULL,
  created_at   timestamp with time zone   DEFAULT now() NOT NULL,
  updated_at   timestamp with time zone   DEFAULT now() NOT NULL
);

CREATE TRIGGER trg_sales_invoice_counters_set_updated_at
  BEFORE UPDATE ON public.sales_invoice_counters
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.sales_invoice_counters
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.sales_invoice_counters
  ADD CONSTRAINT sales_invoice_counters_date_key_check CHECK (date_key ~ '^\d{8}$'::text);

ALTER TABLE public.sales_invoice_counters
  ADD CONSTRAINT sales_invoice_counters_last_value_check CHECK (last_value >= 0);

ALTER TABLE public.sales_invoice_counters
  ADD CONSTRAINT sales_invoice_counters_pkey PRIMARY KEY (tenant_id, invoice_type, date_key);

ALTER TABLE public.sales_invoice_counters
  ADD CONSTRAINT sales_invoice_counters_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.sales_invoice_counters TO anon;

GRANT ALL ON public.sales_invoice_counters TO authenticated;

GRANT ALL ON public.sales_invoice_counters TO service_role;