CREATE TABLE public.cargo_companies (
  id               bigint                   DEFAULT nextval('public.cargo_companies_id_seq'::regclass) NOT NULL,
  parent_tenant_id bigint,
  name             text                     NOT NULL,
  code             text                     NOT NULL,
  phone            text,
  email            text,
  address          text,
  notes            text,
  wallet_entity_id bigint,
  is_active        boolean                  DEFAULT true NOT NULL,
  created_at       timestamp with time zone DEFAULT now() NOT NULL,
  updated_at       timestamp with time zone DEFAULT now() NOT NULL,
  is_default       boolean                  DEFAULT false NOT NULL
);

CREATE UNIQUE INDEX cargo_companies_parent_code_idx ON public.cargo_companies (parent_tenant_id, upper(TRIM(BOTH FROM code)))
  WHERE parent_tenant_id IS NOT NULL;

CREATE UNIQUE INDEX cargo_companies_one_default_per_parent_idx ON public.cargo_companies (parent_tenant_id)
  WHERE is_default = true AND parent_tenant_id IS NOT NULL;

CREATE INDEX cargo_companies_parent_tenant_id_idx ON public.cargo_companies (parent_tenant_id);

CREATE TRIGGER trg_cargo_companies_sync_profile
  AFTER INSERT OR UPDATE ON public.cargo_companies
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_sync_profile_from_cargo_company();

CREATE TRIGGER trg_cargo_companies_updated_at
  BEFORE UPDATE ON public.cargo_companies
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY cargo_companies_delete_policy ON public.cargo_companies
  FOR DELETE
  USING ((parent_tenant_id = public.current_tenant_id()));

CREATE POLICY cargo_companies_insert_policy ON public.cargo_companies
  FOR INSERT
  WITH CHECK ((parent_tenant_id = public.current_tenant_id()));

CREATE POLICY cargo_companies_select_policy ON public.cargo_companies
  FOR SELECT
  USING ((parent_tenant_id = public.current_tenant_id()));

CREATE POLICY cargo_companies_update_policy ON public.cargo_companies
  FOR UPDATE
  USING ((parent_tenant_id = public.current_tenant_id()));

COMMENT ON COLUMN public.cargo_companies.is_default IS 'True for the tenant system default cargo company (code DEFAULT). At most one per parent_tenant_id.';

ALTER SEQUENCE public.cargo_companies_id_seq OWNED BY public.cargo_companies.id;

ALTER TABLE public.cargo_companies
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.cargo_companies
  ADD CONSTRAINT cargo_companies_code_not_blank CHECK (length(TRIM(BOTH FROM code)) > 0);

ALTER TABLE public.cargo_companies
  ADD CONSTRAINT cargo_companies_name_not_blank CHECK (length(TRIM(BOTH FROM name)) > 0);

ALTER TABLE public.cargo_companies
  ADD CONSTRAINT cargo_companies_pkey PRIMARY KEY (id);

ALTER TABLE public.cargo_companies
  ADD CONSTRAINT cargo_companies_parent_tenant_id_fkey FOREIGN KEY (parent_tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.cargo_companies TO anon;

GRANT ALL ON public.cargo_companies TO authenticated;

GRANT ALL ON public.cargo_companies TO service_role;