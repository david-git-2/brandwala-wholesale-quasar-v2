CREATE TABLE public.product_categories (
  id               bigint                   DEFAULT nextval('public.product_categories_id_seq'::regclass) NOT NULL,
  name             text                     NOT NULL,
  value            text                     GENERATED ALWAYS AS (lower(TRIM(BOTH FROM name))) STORED,
  vendor_code      text,
  created_at       timestamp with time zone DEFAULT now() NOT NULL,
  updated_at       timestamp with time zone DEFAULT now() NOT NULL,
  vendor_id        bigint,
  tenant_id        bigint,
  parent_tenant_id bigint
);

CREATE INDEX product_categories_parent_tenant_id_idx ON public.product_categories (parent_tenant_id);

CREATE INDEX product_categories_tenant_id_idx ON public.product_categories (tenant_id);

CREATE INDEX product_categories_vendor_code_idx ON public.product_categories (vendor_code);

CREATE INDEX product_categories_vendor_id_idx ON public.product_categories (vendor_id);

CREATE INDEX product_categories_vendor_id_value_idx ON public.product_categories (vendor_id, VALUE);

CREATE UNIQUE INDEX product_categories_vendor_value_unique ON public.product_categories (COALESCE(upper(TRIM(BOTH FROM vendor_code)), ''::text), VALUE);

CREATE TRIGGER trg_product_categories_set_parent_tenant_id
  BEFORE INSERT OR UPDATE OF tenant_id ON public.product_categories
  FOR EACH ROW
  EXECUTE FUNCTION public.set_parent_tenant_id_from_tenant();

CREATE TRIGGER trg_product_categories_set_updated_at
  BEFORE UPDATE ON public.product_categories
  FOR EACH ROW
  EXECUTE FUNCTION public.set_product_lookup_updated_at_timestamp();

CREATE TRIGGER trg_product_categories_sync_tenant_id
  BEFORE INSERT OR UPDATE OF vendor_id ON public.product_categories
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_lookup_tenant_id();

CREATE TRIGGER trg_product_categories_sync_vendor_reference_fields
  BEFORE INSERT OR UPDATE ON public.product_categories
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_vendor_reference_fields();

CREATE POLICY product_categories_delete_authenticated ON public.product_categories
  FOR DELETE
  TO authenticated
  USING (true);

CREATE POLICY product_categories_insert_authenticated ON public.product_categories
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY product_categories_read_authenticated ON public.product_categories
  FOR SELECT
  TO authenticated
  USING (((EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE ((lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.is_active = true) AND (m.tenant_id IS
    NOT NULL) AND (product_categories.tenant_id = m.tenant_id)))) OR ((parent_tenant_id IS NOT NULL) AND public.user_can_manage_parent_tenant(parent_tenant_id))));

CREATE POLICY product_categories_update_authenticated ON public.product_categories
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

ALTER SEQUENCE public.product_categories_id_seq OWNED BY public.product_categories.id;

ALTER TABLE public.product_categories
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.product_categories
  ADD CONSTRAINT product_categories_name_not_blank CHECK (length(TRIM(BOTH FROM name)) > 0);

ALTER TABLE public.product_categories
  ADD CONSTRAINT product_categories_pkey PRIMARY KEY (id);

ALTER TABLE public.product_categories
  ADD CONSTRAINT product_categories_parent_tenant_id_fkey FOREIGN KEY (parent_tenant_id) REFERENCES public.tenants(id) ON DELETE SET NULL;

ALTER TABLE public.product_categories
  ADD CONSTRAINT product_categories_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

ALTER TABLE public.product_categories
  ADD CONSTRAINT product_categories_vendor_id_fkey FOREIGN KEY (vendor_id) REFERENCES public.vendors(id) ON UPDATE CASCADE ON DELETE SET NULL;

GRANT ALL ON public.product_categories TO anon;

GRANT ALL ON public.product_categories TO authenticated;

GRANT ALL ON public.product_categories TO service_role;