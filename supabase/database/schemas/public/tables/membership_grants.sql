CREATE TABLE public.membership_grants (
  id               bigint                   DEFAULT nextval('public.membership_grants_id_seq'::regclass) NOT NULL,
  membership_id    bigint                   NOT NULL,
  module_key       text                     NOT NULL,
  action           text                     NOT NULL,
  effect           text                     NOT NULL,
  created_by_email text,
  created_at       timestamp with time zone DEFAULT now() NOT NULL,
  updated_at       timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TRIGGER trg_membership_grants_bump_version
  AFTER INSERT OR DELETE OR UPDATE ON public.membership_grants
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_fn_bump_membership_grant_tenant_version();

CREATE TRIGGER trg_membership_grants_updated_at
  BEFORE UPDATE ON public.membership_grants
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

ALTER SEQUENCE public.membership_grants_id_seq OWNED BY public.membership_grants.id;

ALTER TABLE public.membership_grants
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.membership_grants
  ADD CONSTRAINT membership_grants_effect_check CHECK (effect = ANY (ARRAY['allow'::text, 'deny'::text]));

ALTER TABLE public.membership_grants
  ADD CONSTRAINT membership_grants_membership_module_action_unique UNIQUE (membership_id, module_key, action);

ALTER TABLE public.membership_grants
  ADD CONSTRAINT membership_grants_pkey PRIMARY KEY (id);

ALTER TABLE public.membership_grants
  ADD CONSTRAINT membership_grants_membership_id_fkey FOREIGN KEY (membership_id) REFERENCES public.memberships(id) ON DELETE CASCADE;

ALTER TABLE public.membership_grants
  ADD CONSTRAINT membership_grants_module_key_fkey FOREIGN KEY (module_key) REFERENCES public.modules(key) ON DELETE CASCADE;

GRANT ALL ON public.membership_grants TO anon;

GRANT ALL ON public.membership_grants TO authenticated;

GRANT ALL ON public.membership_grants TO service_role;