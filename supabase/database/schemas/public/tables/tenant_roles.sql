CREATE TABLE public.tenant_roles (
  id              bigint                   DEFAULT nextval('public.tenant_roles_id_seq'::regclass) NOT NULL,
  tenant_id       bigint                   NOT NULL,
  scope           text                     NOT NULL,
  name            text                     NOT NULL,
  slug            text                     NOT NULL,
  is_system       boolean                  DEFAULT false NOT NULL,
  is_admin        boolean                  DEFAULT false NOT NULL,
  source_app_role public.app_role,
  is_active       boolean                  DEFAULT true NOT NULL,
  created_at      timestamp with time zone DEFAULT now() NOT NULL,
  updated_at      timestamp with time zone DEFAULT now() NOT NULL
);

CREATE UNIQUE INDEX tenant_roles_one_active_admin_idx ON public.tenant_roles (tenant_id, scope)
  WHERE is_admin = true AND is_active = true;

CREATE TRIGGER trg_tenant_roles_bump_version
  AFTER INSERT OR DELETE OR UPDATE ON public.tenant_roles
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_fn_bump_role_tenant_version();

CREATE TRIGGER trg_tenant_roles_guardrails
  BEFORE DELETE OR UPDATE ON public.tenant_roles
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_fn_tenant_role_guardrails();

CREATE TRIGGER trg_tenant_roles_updated_at
  BEFORE UPDATE ON public.tenant_roles
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

ALTER SEQUENCE public.tenant_roles_id_seq OWNED BY public.tenant_roles.id;

ALTER TABLE public.tenant_roles
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.tenant_roles
  ADD CONSTRAINT tenant_roles_pkey PRIMARY KEY (id);

ALTER TABLE public.tenant_roles
  ADD CONSTRAINT tenant_roles_scope_check CHECK (scope = ANY (ARRAY['app'::text, 'shop'::text]));

ALTER TABLE public.tenant_roles
  ADD CONSTRAINT tenant_roles_tenant_scope_slug_unique UNIQUE (tenant_id, scope, slug);

ALTER TABLE public.tenant_roles
  ADD CONSTRAINT tenant_roles_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.tenant_roles TO anon;

GRANT ALL ON public.tenant_roles TO authenticated;

GRANT ALL ON public.tenant_roles TO service_role;