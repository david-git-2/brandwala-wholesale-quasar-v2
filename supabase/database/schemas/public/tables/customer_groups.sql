CREATE TABLE public.customer_groups (
  id               bigint                   DEFAULT nextval('public.customer_groups_id_seq'::regclass) NOT NULL,
  name             text                     NOT NULL,
  tenant_id        bigint                   NOT NULL,
  is_active        boolean                  DEFAULT true NOT NULL,
  created_at       timestamp with time zone DEFAULT now() NOT NULL,
  updated_at       timestamp with time zone DEFAULT now() NOT NULL,
  accent_color     text,
  parent_tenant_id bigint                   NOT NULL,
  deleted_at       timestamp with time zone
);

CREATE INDEX customer_groups_parent_live_idx ON public.customer_groups (parent_tenant_id)
  WHERE deleted_at IS NULL;

CREATE INDEX customer_groups_parent_tenant_id_idx ON public.customer_groups (parent_tenant_id);

CREATE INDEX customer_groups_tenant_id_idx ON public.customer_groups (tenant_id);

CREATE TRIGGER trg_customer_groups_guard_administer_active
  BEFORE UPDATE ON public.customer_groups
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_customer_groups_guard_administer_active();

CREATE TRIGGER trg_customer_groups_soft_delete_phone_unique
  AFTER UPDATE OF deleted_at ON public.customer_groups
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_customer_groups_soft_delete_phone_unique();

CREATE TRIGGER trg_customer_groups_sync_parent_tenant
  BEFORE INSERT OR UPDATE OF tenant_id, parent_tenant_id ON public.customer_groups
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_customer_groups_sync_parent_tenant();

CREATE TRIGGER trg_customer_groups_sync_profile
  AFTER UPDATE OF accent_color, is_active, deleted_at ON public.customer_groups
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_sync_profile_from_customer_group();

CREATE TRIGGER trg_customer_groups_updated_at
  BEFORE UPDATE ON public.customer_groups
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY customer_groups_delete ON public.customer_groups
  FOR DELETE
  TO authenticated
  USING (public.can_administer_customer_group(tenant_id));

CREATE POLICY customer_groups_insert ON public.customer_groups
  FOR INSERT
  TO authenticated
  WITH CHECK (public.can_administer_customer_group(tenant_id));

CREATE POLICY customer_groups_update ON public.customer_groups
  FOR UPDATE
  TO authenticated
  USING (public.can_manage_customer_group(tenant_id))
  WITH CHECK (public.can_manage_customer_group(tenant_id));

CREATE POLICY customer_groups_select ON public.customer_groups
  FOR SELECT
  TO authenticated
  USING ((public.can_manage_customer_group(COALESCE(parent_tenant_id, tenant_id)) OR public.is_tenant_staff(COALESCE(parent_tenant_id, tenant_id)) OR (EXISTS ( SELECT 1
   FROM public.tenants child
  WHERE ((child.parent_id = COALESCE(customer_groups.parent_tenant_id, customer_groups.tenant_id)) AND public.is_tenant_staff(child.id))))));

ALTER SEQUENCE public.customer_groups_id_seq OWNED BY public.customer_groups.id;

ALTER TABLE public.customer_groups
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.customer_groups
  ADD CONSTRAINT customer_groups_pkey PRIMARY KEY (id);

ALTER TABLE public.customer_groups
  ADD CONSTRAINT customer_groups_parent_tenant_id_fkey FOREIGN KEY (parent_tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

ALTER TABLE public.customer_groups
  ADD CONSTRAINT customer_groups_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.customer_groups TO anon;

GRANT ALL ON public.customer_groups TO authenticated;

GRANT ALL ON public.customer_groups TO service_role;