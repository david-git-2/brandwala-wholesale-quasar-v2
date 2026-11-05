CREATE TABLE public.invoice_brands (
  id               bigint                   DEFAULT nextval('public.invoice_brands_id_seq'::regclass) NOT NULL,
  parent_tenant_id bigint                   NOT NULL,
  name             text                     NOT NULL,
  address          text                     NOT NULL,
  created_at       timestamp with time zone DEFAULT now() NOT NULL,
  updated_at       timestamp with time zone DEFAULT now() NOT NULL
);

CREATE INDEX invoice_brands_parent_tenant_id_idx ON public.invoice_brands (parent_tenant_id);

CREATE TRIGGER trg_invoice_brands_set_updated_at
  BEFORE UPDATE ON public.invoice_brands
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY invoice_brands_delete ON public.invoice_brands
  FOR DELETE
  TO authenticated
  USING ((public.membership_has_module_action(parent_tenant_id, 'invoice_brand'::text, 'edit'::text) OR public.user_can_manage_parent_tenant(parent_tenant_id)));

CREATE POLICY invoice_brands_insert ON public.invoice_brands
  FOR INSERT
  TO authenticated
  WITH CHECK ((public.membership_has_module_action(parent_tenant_id, 'invoice_brand'::text, 'edit'::text) OR public.user_can_manage_parent_tenant(parent_tenant_id)));

CREATE POLICY invoice_brands_select ON public.invoice_brands
  FOR SELECT
  TO authenticated
  USING ((public.has_active_tenant_membership(parent_tenant_id) OR public.user_can_manage_parent_tenant(parent_tenant_id)));

CREATE POLICY invoice_brands_update ON public.invoice_brands
  FOR UPDATE
  TO authenticated
  USING ((public.membership_has_module_action(parent_tenant_id, 'invoice_brand'::text, 'edit'::text) OR public.user_can_manage_parent_tenant(parent_tenant_id)))
  WITH CHECK ((public.membership_has_module_action(parent_tenant_id, 'invoice_brand'::text, 'edit'::text) OR public.user_can_manage_parent_tenant(parent_tenant_id)));

ALTER SEQUENCE public.invoice_brands_id_seq OWNED BY public.invoice_brands.id;

ALTER TABLE public.invoice_brands
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.invoice_brands
  ADD CONSTRAINT invoice_brands_parent_tenant_id_name_key UNIQUE (parent_tenant_id, name);

ALTER TABLE public.invoice_brands
  ADD CONSTRAINT invoice_brands_pkey PRIMARY KEY (id);

ALTER TABLE public.invoice_brands
  ADD CONSTRAINT invoice_brands_parent_tenant_id_fkey FOREIGN KEY (parent_tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.invoice_brands TO anon;

GRANT ALL ON public.invoice_brands TO authenticated;

GRANT ALL ON public.invoice_brands TO service_role;