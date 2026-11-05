CREATE TABLE public.tenant_module_submodules (
  id                bigint                   DEFAULT nextval('public.tenant_module_submodules_id_seq'::regclass) NOT NULL,
  tenant_id         bigint                   NOT NULL,
  parent_module_key text                     NOT NULL,
  submodule_key     text                     NOT NULL,
  is_enabled        boolean                  DEFAULT true NOT NULL,
  created_at        timestamp with time zone DEFAULT now() NOT NULL,
  updated_at        timestamp with time zone DEFAULT now() NOT NULL
);

CREATE INDEX tenant_module_submodules_tenant_parent_idx ON public.tenant_module_submodules (tenant_id, parent_module_key);

CREATE TRIGGER trg_tenant_module_submodules_updated_at
  BEFORE UPDATE ON public.tenant_module_submodules
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY tenant_module_submodules_superadmin_all ON public.tenant_module_submodules
  TO authenticated
  USING (public.is_superadmin())
  WITH CHECK (public.is_superadmin());

ALTER SEQUENCE public.tenant_module_submodules_id_seq OWNED BY public.tenant_module_submodules.id;

ALTER TABLE public.tenant_module_submodules
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.tenant_module_submodules
  ADD CONSTRAINT tenant_module_submodules_parent_module_key_fkey FOREIGN KEY (parent_module_key) REFERENCES public.modules(key) ON DELETE CASCADE;

ALTER TABLE public.tenant_module_submodules
  ADD CONSTRAINT tenant_module_submodules_pkey PRIMARY KEY (id);

ALTER TABLE public.tenant_module_submodules
  ADD CONSTRAINT tenant_module_submodules_submodule_key_fkey FOREIGN KEY (submodule_key) REFERENCES public.modules(key) ON DELETE CASCADE;

ALTER TABLE public.tenant_module_submodules
  ADD CONSTRAINT tenant_module_submodules_tenant_id_submodule_key_key UNIQUE (tenant_id, submodule_key);

ALTER TABLE public.tenant_module_submodules
  ADD CONSTRAINT tenant_module_submodules_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.tenant_module_submodules TO anon;

GRANT ALL ON public.tenant_module_submodules TO authenticated;

GRANT ALL ON public.tenant_module_submodules TO service_role;