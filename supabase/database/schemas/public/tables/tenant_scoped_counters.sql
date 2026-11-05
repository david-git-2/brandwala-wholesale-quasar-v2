CREATE TABLE public.tenant_scoped_counters (
  tenant_id  bigint                   NOT NULL,
  scope      text                     NOT NULL,
  last_value bigint                   DEFAULT 0 NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE INDEX tenant_scoped_counters_scope_idx ON public.tenant_scoped_counters (scope);

CREATE TRIGGER trg_tenant_scoped_counters_set_updated_at
  BEFORE UPDATE ON public.tenant_scoped_counters
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.tenant_scoped_counters
  ADD CONSTRAINT tenant_scoped_counters_last_value_check CHECK (last_value >= 0);

ALTER TABLE public.tenant_scoped_counters
  ADD CONSTRAINT tenant_scoped_counters_pkey PRIMARY KEY (tenant_id, scope);

ALTER TABLE public.tenant_scoped_counters
  ADD CONSTRAINT tenant_scoped_counters_scope_check CHECK (scope = ANY (ARRAY['shipment'::text, 'order'::text]));

ALTER TABLE public.tenant_scoped_counters
  ADD CONSTRAINT tenant_scoped_counters_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

ALTER TABLE public.tenant_scoped_counters ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.tenant_scoped_counters FROM PUBLIC, anon, authenticated;
GRANT ALL ON TABLE public.tenant_scoped_counters TO service_role;