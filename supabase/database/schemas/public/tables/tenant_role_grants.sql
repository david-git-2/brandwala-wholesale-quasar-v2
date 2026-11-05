CREATE TABLE public.tenant_role_grants (
  id               bigint                   DEFAULT nextval('public.tenant_role_grants_id_seq'::regclass) NOT NULL,
  tenant_role_id   bigint                   NOT NULL,
  module_key       text                     NOT NULL,
  action           text                     NOT NULL,
  allowed          boolean                  NOT NULL,
  updated_by_email text,
  created_at       timestamp with time zone DEFAULT now() NOT NULL,
  updated_at       timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TRIGGER trg_tenant_role_grants_bump_version
  AFTER INSERT OR DELETE OR UPDATE ON public.tenant_role_grants
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_fn_bump_grant_tenant_version();

CREATE TRIGGER trg_tenant_role_grants_updated_at
  BEFORE UPDATE ON public.tenant_role_grants
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

ALTER SEQUENCE public.tenant_role_grants_id_seq OWNED BY public.tenant_role_grants.id;

ALTER TABLE public.tenant_role_grants
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.tenant_role_grants
  ADD CONSTRAINT tenant_role_grants_module_key_fkey FOREIGN KEY (module_key) REFERENCES public.modules(key) ON DELETE CASCADE;

ALTER TABLE public.tenant_role_grants
  ADD CONSTRAINT tenant_role_grants_pkey PRIMARY KEY (id);

ALTER TABLE public.tenant_role_grants
  ADD CONSTRAINT tenant_role_grants_role_module_action_unique UNIQUE (tenant_role_id, module_key, action);

ALTER TABLE public.tenant_role_grants
  ADD CONSTRAINT tenant_role_grants_tenant_role_id_fkey FOREIGN KEY (tenant_role_id) REFERENCES public.tenant_roles(id) ON DELETE CASCADE;

GRANT ALL ON public.tenant_role_grants TO anon;

GRANT ALL ON public.tenant_role_grants TO authenticated;

GRANT ALL ON public.tenant_role_grants TO service_role;