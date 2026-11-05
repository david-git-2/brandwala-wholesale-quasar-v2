CREATE TABLE public.tenant_modules (
  id         bigint                   DEFAULT nextval('public.tenant_modules_id_seq'::regclass) NOT NULL,
  tenant_id  bigint                   NOT NULL,
  module_key text                     NOT NULL,
  is_active  boolean                  DEFAULT true NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE INDEX tenant_modules_tenant_id_idx ON public.tenant_modules (tenant_id);

CREATE INDEX tenant_modules_module_key_idx ON public.tenant_modules (module_key);

CREATE TRIGGER trg_tenant_modules_bump_version
  AFTER INSERT OR DELETE OR UPDATE ON public.tenant_modules
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_fn_bump_tenant_modules_version();

CREATE TRIGGER trg_tenant_modules_disable_guardrails
  BEFORE UPDATE ON public.tenant_modules
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_fn_tenant_modules_disable_guardrails();

CREATE TRIGGER trg_tenant_modules_updated_at
  BEFORE UPDATE ON public.tenant_modules
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY superadmin_can_manage_tenant_modules ON public.tenant_modules
  TO authenticated
  USING (public.is_superadmin())
  WITH CHECK (public.is_superadmin());

ALTER SEQUENCE public.tenant_modules_id_seq OWNED BY public.tenant_modules.id;

ALTER TABLE public.tenant_modules
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.tenant_modules
  ADD CONSTRAINT tenant_modules_module_key_fkey FOREIGN KEY (module_key) REFERENCES public.modules(key) ON DELETE CASCADE;

ALTER TABLE public.tenant_modules
  ADD CONSTRAINT tenant_modules_pkey PRIMARY KEY (id);

ALTER TABLE public.tenant_modules
  ADD CONSTRAINT tenant_modules_tenant_id_module_key_key UNIQUE (tenant_id, module_key);

ALTER TABLE public.tenant_modules
  ADD CONSTRAINT tenant_modules_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.tenant_modules TO anon;

GRANT ALL ON public.tenant_modules TO authenticated;

GRANT ALL ON public.tenant_modules TO service_role;