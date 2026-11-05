CREATE TABLE public.module_actions (
  id                  bigint                   DEFAULT nextval('public.module_actions_id_seq'::regclass) NOT NULL,
  module_key          text                     NOT NULL,
  action              text                     NOT NULL,
  description         text,
  scope               text                     NOT NULL,
  tenant_configurable boolean                  DEFAULT true NOT NULL,
  is_active           boolean                  DEFAULT true NOT NULL,
  created_at          timestamp with time zone DEFAULT now() NOT NULL,
  updated_at          timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TRIGGER trg_module_actions_updated_at
  BEFORE UPDATE ON public.module_actions
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY module_actions_select_all ON public.module_actions
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY module_actions_write_superadmin ON public.module_actions
  TO authenticated
  USING (public.is_superadmin())
  WITH CHECK (public.is_superadmin());

ALTER SEQUENCE public.module_actions_id_seq OWNED BY public.module_actions.id;

ALTER TABLE public.module_actions
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.module_actions
  ADD CONSTRAINT module_actions_module_key_action_scope_unique UNIQUE (module_key, action, scope);

ALTER TABLE public.module_actions
  ADD CONSTRAINT module_actions_pkey PRIMARY KEY (id);

ALTER TABLE public.module_actions
  ADD CONSTRAINT module_actions_scope_check CHECK (scope = ANY (ARRAY['app'::text, 'shop'::text, 'platform'::text, 'investor'::text]));

ALTER TABLE public.module_actions
  ADD CONSTRAINT module_actions_module_key_fkey FOREIGN KEY (module_key) REFERENCES public.modules(key) ON DELETE CASCADE;

GRANT ALL ON public.module_actions TO anon;

GRANT ALL ON public.module_actions TO authenticated;

GRANT ALL ON public.module_actions TO service_role;