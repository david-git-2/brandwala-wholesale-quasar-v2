CREATE TABLE public.tenants (
  id                 bigint                   DEFAULT nextval('public.tenants_id_seq'::regclass) NOT NULL,
  name               text                     NOT NULL,
  slug               text                     NOT NULL,
  is_active          boolean                  DEFAULT true NOT NULL,
  created_at         timestamp with time zone DEFAULT now() NOT NULL,
  updated_at         timestamp with time zone DEFAULT now() NOT NULL,
  public_domain      text,
  parent_id          bigint,
  preference         jsonb                    DEFAULT '{}'::jsonb NOT NULL,
  base_currency_code text                     DEFAULT 'BDT'::text NOT NULL
);

CREATE INDEX tenants_parent_id_idx ON public.tenants (parent_id);

CREATE UNIQUE INDEX tenants_public_domain_unique_idx ON public.tenants (lower(TRIM(BOTH FROM public_domain)))
  WHERE NULLIF(TRIM(BOTH FROM public_domain), ''::text) IS NOT NULL;

CREATE TRIGGER on_tenant_created_retail_settings
  AFTER INSERT ON public.tenants
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_tenant_retail_settings();

CREATE TRIGGER trg_after_tenant_insert
  AFTER INSERT ON public.tenants
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_fn_seed_new_tenant();

CREATE TRIGGER trg_auto_enable_cashbook
  AFTER INSERT ON public.tenants
  FOR EACH ROW
  EXECUTE FUNCTION public.auto_enable_cashbook_for_new_tenant();

CREATE TRIGGER trg_auto_enable_customer_module
  AFTER INSERT ON public.tenants
  FOR EACH ROW
  EXECUTE FUNCTION public.auto_enable_customer_module_for_new_tenant();

CREATE TRIGGER trg_auto_enable_investor_capital
  AFTER INSERT ON public.tenants
  FOR EACH ROW
  EXECUTE FUNCTION public.auto_enable_investor_capital_for_root_tenant();

CREATE TRIGGER trg_tenants_enforce_one_layer_hierarchy
  BEFORE INSERT OR UPDATE OF parent_id ON public.tenants
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_tenant_one_layer_hierarchy();

CREATE TRIGGER trg_tenants_sync_profile
  AFTER INSERT OR UPDATE OF name, is_active ON public.tenants
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_sync_profile_from_tenant();

CREATE TRIGGER trg_tenants_updated_at
  BEFORE UPDATE ON public.tenants
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY members_can_view_tenants ON public.tenants
  FOR SELECT
  TO authenticated
  USING ((public.is_superadmin() OR (EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE ((m.tenant_id = tenants.id) AND (lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.is_active = true)))) OR ((parent_id IS
    NOT NULL) AND public.user_can_manage_parent_tenant(parent_id))));

CREATE POLICY superadmin_can_manage_tenants ON public.tenants
  TO authenticated
  USING (public.is_superadmin())
  WITH CHECK (public.is_superadmin());

ALTER SEQUENCE public.tenants_id_seq OWNED BY public.tenants.id;

ALTER TABLE public.tenants
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.tenants
  ADD CONSTRAINT tenants_base_currency_code_trimmed CHECK (btrim(base_currency_code) <> ''::text);

ALTER TABLE public.tenants
  ADD CONSTRAINT tenants_parent_id_check CHECK (parent_id IS NULL OR parent_id <> id);

ALTER TABLE public.tenants
  ADD CONSTRAINT tenants_pkey PRIMARY KEY (id);

ALTER TABLE public.tenants
  ADD CONSTRAINT tenants_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.tenants(id) ON DELETE SET NULL;

ALTER TABLE public.tenants
  ADD CONSTRAINT tenants_slug_key UNIQUE (slug);

GRANT ALL ON public.tenants TO anon;

GRANT ALL ON public.tenants TO authenticated;

GRANT ALL ON public.tenants TO service_role;