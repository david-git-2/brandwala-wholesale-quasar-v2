CREATE TABLE public.system_role_templates (
  id         bigint                   DEFAULT nextval('public.system_role_templates_id_seq'::regclass) NOT NULL,
  scope      text                     NOT NULL,
  role_slug  text                     NOT NULL,
  module_key text                     NOT NULL,
  action     text                     NOT NULL,
  allowed    boolean                  NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TRIGGER trg_system_role_templates_updated_at
  BEFORE UPDATE ON public.system_role_templates
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY system_role_templates_select_all ON public.system_role_templates
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY system_role_templates_write_superadmin ON public.system_role_templates
  TO authenticated
  USING (public.is_superadmin())
  WITH CHECK (public.is_superadmin());

ALTER SEQUENCE public.system_role_templates_id_seq OWNED BY public.system_role_templates.id;

ALTER TABLE public.system_role_templates
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.system_role_templates
  ADD CONSTRAINT system_role_templates_module_key_fkey FOREIGN KEY (module_key) REFERENCES public.modules(key) ON DELETE CASCADE;

ALTER TABLE public.system_role_templates
  ADD CONSTRAINT system_role_templates_pkey PRIMARY KEY (id);

ALTER TABLE public.system_role_templates
  ADD CONSTRAINT system_role_templates_scope_check CHECK (scope = ANY (ARRAY['app'::text, 'shop'::text]));

ALTER TABLE public.system_role_templates
  ADD CONSTRAINT system_role_templates_scope_slug_module_action_unique UNIQUE (scope, role_slug, module_key, action);

GRANT ALL ON public.system_role_templates TO anon;

GRANT ALL ON public.system_role_templates TO authenticated;

GRANT ALL ON public.system_role_templates TO service_role;