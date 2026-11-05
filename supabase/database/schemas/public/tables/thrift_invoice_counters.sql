CREATE TABLE public.thrift_invoice_counters (
  tenant_id  bigint                   NOT NULL,
  year_month text                     NOT NULL,
  last_value bigint                   DEFAULT 0 NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TRIGGER trg_thrift_invoice_counters_set_updated_at
  BEFORE UPDATE ON public.thrift_invoice_counters
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.thrift_invoice_counters
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.thrift_invoice_counters
  ADD CONSTRAINT thrift_invoice_counters_last_value_check CHECK (last_value >= 0);

ALTER TABLE public.thrift_invoice_counters
  ADD CONSTRAINT thrift_invoice_counters_pkey PRIMARY KEY (tenant_id, year_month);

ALTER TABLE public.thrift_invoice_counters
  ADD CONSTRAINT thrift_invoice_counters_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

ALTER TABLE public.thrift_invoice_counters
  ADD CONSTRAINT thrift_invoice_counters_year_month_check CHECK (year_month ~ '^\d{4}-\d{2}$'::text);

GRANT ALL ON public.thrift_invoice_counters TO anon;

GRANT ALL ON public.thrift_invoice_counters TO authenticated;

GRANT ALL ON public.thrift_invoice_counters TO service_role;