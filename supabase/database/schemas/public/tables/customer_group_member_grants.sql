CREATE TABLE public.customer_group_member_grants (
  id                       bigint                   DEFAULT nextval('public.customer_group_member_grants_id_seq'::regclass) NOT NULL,
  customer_group_member_id bigint                   NOT NULL,
  module_key               text                     NOT NULL,
  action                   text                     NOT NULL,
  effect                   text                     NOT NULL,
  created_at               timestamp with time zone DEFAULT now() NOT NULL,
  updated_at               timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TRIGGER trg_cgm_grants_bump_version
  AFTER INSERT OR DELETE OR UPDATE ON public.customer_group_member_grants
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_fn_bump_cgm_grant_tenant_version();

CREATE TRIGGER trg_customer_group_member_grants_updated_at
  BEFORE UPDATE ON public.customer_group_member_grants
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

ALTER SEQUENCE public.customer_group_member_grants_id_seq OWNED BY public.customer_group_member_grants.id;

ALTER TABLE public.customer_group_member_grants
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.customer_group_member_grants
  ADD CONSTRAINT customer_group_member_grants_cgm_module_action_unique UNIQUE (customer_group_member_id, module_key, action);

ALTER TABLE public.customer_group_member_grants
  ADD CONSTRAINT customer_group_member_grants_effect_check CHECK (effect = ANY (ARRAY['allow'::text, 'deny'::text]));

ALTER TABLE public.customer_group_member_grants
  ADD CONSTRAINT customer_group_member_grants_pkey PRIMARY KEY (id);

ALTER TABLE public.customer_group_member_grants
  ADD CONSTRAINT customer_group_member_grants_customer_group_member_id_fkey FOREIGN KEY (customer_group_member_id) REFERENCES public.customer_group_members(id) ON DELETE CASCADE;

ALTER TABLE public.customer_group_member_grants
  ADD CONSTRAINT customer_group_member_grants_module_key_fkey FOREIGN KEY (module_key) REFERENCES public.modules(key) ON DELETE CASCADE;

GRANT ALL ON public.customer_group_member_grants TO anon;

GRANT ALL ON public.customer_group_member_grants TO authenticated;

GRANT ALL ON public.customer_group_member_grants TO service_role;