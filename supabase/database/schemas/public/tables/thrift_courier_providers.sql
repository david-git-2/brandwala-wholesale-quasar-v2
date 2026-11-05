CREATE TABLE public.thrift_courier_providers (
  id           bigint                   DEFAULT nextval('public.thrift_courier_providers_id_seq'::regclass) NOT NULL,
  tenant_id    bigint,
  code         text                     NOT NULL,
  name         text                     NOT NULL,
  country_code text                     DEFAULT 'BD'::text NOT NULL,
  is_system    boolean                  DEFAULT false NOT NULL,
  is_active    boolean                  DEFAULT true NOT NULL,
  sort_order   integer                  DEFAULT 100 NOT NULL,
  meta         jsonb                    DEFAULT '{}'::jsonb NOT NULL,
  created_at   timestamp with time zone DEFAULT now() NOT NULL,
  updated_at   timestamp with time zone DEFAULT now() NOT NULL
);

CREATE UNIQUE INDEX thrift_courier_providers_system_code_uidx ON public.thrift_courier_providers (code)
  WHERE tenant_id IS NULL;

CREATE UNIQUE INDEX thrift_courier_providers_tenant_code_uidx ON public.thrift_courier_providers (tenant_id, code)
  WHERE tenant_id IS NOT NULL;

CREATE INDEX idx_thrift_courier_providers_picker ON public.thrift_courier_providers (is_active, sort_order, name);

CREATE TRIGGER trg_thrift_courier_providers_guard_system
  BEFORE DELETE OR UPDATE ON public.thrift_courier_providers
  FOR EACH ROW
  EXECUTE FUNCTION public.thrift_courier_providers_guard_system();

CREATE TRIGGER trg_thrift_courier_providers_set_updated_at
  BEFORE UPDATE ON public.thrift_courier_providers
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY thrift_courier_providers_delete ON public.thrift_courier_providers
  FOR DELETE
  TO authenticated
  USING (((is_system = false) AND (tenant_id IS
    NOT NULL) AND
    (public.membership_has_module_action(tenant_id, 'thrift_sales'::text, 'edit'::text) OR public.membership_has_module_action(tenant_id, 'thrift_sales'::text, 'delete'::text) OR
    public.membership_has_module_action(tenant_id, 'thrift_settings'::text, 'edit'::text))));

CREATE POLICY thrift_courier_providers_insert ON public.thrift_courier_providers
  FOR INSERT
  TO authenticated
  WITH CHECK (((is_system = false) AND (tenant_id IS
    NOT NULL) AND
    (public.membership_has_module_action(tenant_id, 'thrift_sales'::text, 'create'::text) OR public.membership_has_module_action(tenant_id, 'thrift_sales'::text, 'edit'::text) OR
    public.membership_has_module_action(tenant_id, 'thrift_settings'::text, 'edit'::text))));

CREATE POLICY thrift_courier_providers_select ON public.thrift_courier_providers
  FOR SELECT
  TO authenticated
  USING ((((tenant_id IS NULL) AND (is_system = true) AND (EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE ((lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.is_active = true))))) OR ((tenant_id IS
    NOT NULL) AND
    (public.membership_has_module_action(tenant_id, 'thrift_sales'::text, 'view'::text) OR public.membership_has_module_action(tenant_id, 'thrift_settings'::text, 'view'::text)))));

CREATE POLICY thrift_courier_providers_update ON public.thrift_courier_providers
  FOR UPDATE
  TO authenticated
  USING (((is_system = false) AND (tenant_id IS
    NOT NULL) AND
    (public.membership_has_module_action(tenant_id, 'thrift_sales'::text, 'create'::text) OR public.membership_has_module_action(tenant_id, 'thrift_sales'::text, 'edit'::text) OR
    public.membership_has_module_action(tenant_id, 'thrift_settings'::text, 'edit'::text))))
  WITH CHECK (((is_system = false) AND (tenant_id IS
    NOT NULL) AND
    (public.membership_has_module_action(tenant_id, 'thrift_sales'::text, 'create'::text) OR public.membership_has_module_action(tenant_id, 'thrift_sales'::text, 'edit'::text) OR
    public.membership_has_module_action(tenant_id, 'thrift_settings'::text, 'edit'::text))));

COMMENT ON TABLE public.thrift_courier_providers IS 'System (tenant_id null, is_system) BD catalog + tenant custom couriers for Online sales.';

COMMENT ON COLUMN public.thrift_courier_providers.meta IS 'JSONB extension bag for future extras (notes, website, support_phone, tracking_url_template). Not fee math.';

ALTER SEQUENCE public.thrift_courier_providers_id_seq OWNED BY public.thrift_courier_providers.id;

ALTER TABLE public.thrift_courier_providers
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.thrift_courier_providers
  ADD CONSTRAINT thrift_courier_providers_code_nonempty CHECK (length(TRIM(BOTH FROM code)) > 0);

ALTER TABLE public.thrift_courier_providers
  ADD CONSTRAINT thrift_courier_providers_name_nonempty CHECK (length(TRIM(BOTH FROM name)) > 0);

ALTER TABLE public.thrift_courier_providers
  ADD CONSTRAINT thrift_courier_providers_pkey PRIMARY KEY (id);

ALTER TABLE public.thrift_courier_providers
  ADD CONSTRAINT thrift_courier_providers_system_tenant_check CHECK (is_system = true AND tenant_id IS NULL OR is_system = false AND tenant_id IS NOT NULL);

ALTER TABLE public.thrift_courier_providers
  ADD CONSTRAINT thrift_courier_providers_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.thrift_courier_providers TO anon;

GRANT ALL ON public.thrift_courier_providers TO authenticated;

GRANT ALL ON public.thrift_courier_providers TO service_role;