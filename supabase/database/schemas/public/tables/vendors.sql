CREATE TABLE public.vendors (
  id               bigint                   DEFAULT nextval('public.vendors_id_seq'::regclass) NOT NULL,
  name             text                     NOT NULL,
  code             text                     NOT NULL,
  market_code      text                     NOT NULL,
  email            text,
  phone            text,
  address          text,
  website          text,
  created_at       timestamp with time zone DEFAULT now() NOT NULL,
  updated_at       timestamp with time zone DEFAULT now() NOT NULL,
  parent_tenant_id bigint,
  is_default       boolean                  DEFAULT false NOT NULL
);

CREATE INDEX vendors_market_code_idx ON public.vendors (market_code);

CREATE UNIQUE INDEX vendors_global_code_unique_idx ON public.vendors (upper(TRIM(BOTH FROM code)))
  WHERE parent_tenant_id IS NULL;

CREATE INDEX vendors_parent_tenant_id_idx ON public.vendors (parent_tenant_id);

CREATE UNIQUE INDEX vendors_parent_code_unique_idx ON public.vendors (parent_tenant_id, upper(TRIM(BOTH FROM code)))
  WHERE parent_tenant_id IS NOT NULL;

CREATE UNIQUE INDEX vendors_one_default_per_parent_idx ON public.vendors (parent_tenant_id)
  WHERE is_default = true AND parent_tenant_id IS NOT NULL;

CREATE TRIGGER trg_vendors_normalize_fields
  BEFORE INSERT OR UPDATE ON public.vendors
  FOR EACH ROW
  EXECUTE FUNCTION public.normalize_vendor_fields();

CREATE TRIGGER trg_vendors_sync_profile
  AFTER INSERT OR UPDATE ON public.vendors
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_sync_profile_from_vendor();

CREATE TRIGGER trg_vendors_updated_at
  BEFORE UPDATE ON public.vendors
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY vendors_delete ON public.vendors
  FOR DELETE
  TO authenticated
  USING (((public.is_superadmin() AND (parent_tenant_id IS NULL)) OR ((parent_tenant_id IS NOT NULL) AND public.is_network_owner(parent_tenant_id)) OR (EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE ((lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.role = 'admin'::public.app_role) AND (m.is_active = true) AND (m.tenant_id IS
    NOT NULL) AND (vendors.parent_tenant_id = m.tenant_id))))));

CREATE POLICY vendors_insert ON public.vendors
  FOR INSERT
  TO authenticated
  WITH CHECK (((public.is_superadmin() AND (parent_tenant_id IS NULL)) OR ((parent_tenant_id IS NOT NULL) AND public.is_network_owner(parent_tenant_id)) OR (EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE ((lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.role = 'admin'::public.app_role) AND (m.is_active = true) AND (m.tenant_id IS
    NOT NULL) AND (vendors.parent_tenant_id = m.tenant_id))))));

CREATE POLICY vendors_select ON public.vendors
  FOR SELECT
  TO authenticated
  USING (((public.is_superadmin() AND (parent_tenant_id IS NULL)) OR (EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE ((lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.role = 'admin'::public.app_role) AND (m.is_active = true) AND (m.tenant_id IS
    NOT NULL) AND (vendors.parent_tenant_id = m.tenant_id)))) OR ((parent_tenant_id IS NOT NULL) AND public.user_can_manage_parent_tenant(parent_tenant_id))));

CREATE POLICY vendors_update ON public.vendors
  FOR UPDATE
  TO authenticated
  USING (((public.is_superadmin() AND (parent_tenant_id IS NULL)) OR ((parent_tenant_id IS NOT NULL) AND public.is_network_owner(parent_tenant_id)) OR (EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE ((lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.role = 'admin'::public.app_role) AND (m.is_active = true) AND (m.tenant_id IS
    NOT NULL) AND (vendors.parent_tenant_id = m.tenant_id))))))
  WITH CHECK (((public.is_superadmin() AND (parent_tenant_id IS NULL)) OR ((parent_tenant_id IS NOT NULL) AND public.is_network_owner(parent_tenant_id)) OR (EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE ((lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.role = 'admin'::public.app_role) AND (m.is_active = true) AND (m.tenant_id IS
    NOT NULL) AND (vendors.parent_tenant_id = m.tenant_id))))));

COMMENT ON COLUMN public.vendors.is_default IS 'True for the tenant system default vendor (code DEFAULT). At most one per parent_tenant_id.';

ALTER SEQUENCE public.vendors_id_seq OWNED BY public.vendors.id;

ALTER TABLE public.vendors
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.vendors
  ADD CONSTRAINT vendors_code_not_blank CHECK (length(TRIM(BOTH FROM code)) > 0);

ALTER TABLE public.vendors
  ADD CONSTRAINT vendors_market_code_fkey FOREIGN KEY (market_code) REFERENCES public.markets(code);

ALTER TABLE public.vendors
  ADD CONSTRAINT vendors_market_code_not_blank CHECK (length(TRIM(BOTH FROM market_code)) > 0);

ALTER TABLE public.vendors
  ADD CONSTRAINT vendors_name_not_blank CHECK (length(TRIM(BOTH FROM name)) > 0);

ALTER TABLE public.vendors
  ADD CONSTRAINT vendors_parent_tenant_id_fkey FOREIGN KEY (parent_tenant_id) REFERENCES public.tenants(id) ON DELETE SET NULL;

ALTER TABLE public.vendors
  ADD CONSTRAINT vendors_pkey PRIMARY KEY (id);

GRANT ALL ON public.vendors TO anon;

GRANT ALL ON public.vendors TO authenticated;

GRANT ALL ON public.vendors TO service_role;