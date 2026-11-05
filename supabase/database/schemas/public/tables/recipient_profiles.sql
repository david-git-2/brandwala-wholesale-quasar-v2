CREATE TABLE public.recipient_profiles (
  id               bigint                   DEFAULT nextval('public.recipient_profiles_id_seq'::regclass) NOT NULL,
  tenant_id        bigint,
  name             text                     NOT NULL,
  address          text                     NOT NULL,
  phone            text                     NOT NULL,
  created_at       timestamp with time zone DEFAULT now() NOT NULL,
  updated_at       timestamp with time zone DEFAULT now() NOT NULL,
  secondary_phone  text,
  district         text,
  thana            text,
  addresses        jsonb                    DEFAULT '[]'::jsonb NOT NULL,
  parent_tenant_id bigint
);

CREATE INDEX recipient_profiles_parent_tenant_id_idx ON public.recipient_profiles (parent_tenant_id);

CREATE INDEX recipient_profiles_name_idx ON public.recipient_profiles (name);

CREATE UNIQUE INDEX recipient_profiles_tenant_phone_uidx ON public.recipient_profiles (tenant_id, phone);

CREATE INDEX recipient_profiles_tenant_id_idx ON public.recipient_profiles (tenant_id);

CREATE TRIGGER trg_recipient_profiles_set_parent_tenant_id
  BEFORE INSERT OR UPDATE OF tenant_id ON public.recipient_profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.set_parent_tenant_id_from_tenant();

CREATE TRIGGER trg_recipient_profiles_set_updated_at
  BEFORE UPDATE ON public.recipient_profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY recipient_profiles_select ON public.recipient_profiles
  FOR SELECT
  TO authenticated
  USING ((public.has_active_tenant_membership(tenant_id) OR ((parent_tenant_id IS
    NOT NULL) AND (public.has_active_tenant_membership(parent_tenant_id) OR public.user_can_manage_parent_tenant(parent_tenant_id)))));

CREATE POLICY recipient_profiles_write ON public.recipient_profiles
  TO authenticated
  USING
    ((public.membership_has_module_action(tenant_id, 'recipient_profile'::text, 'edit'::text) OR public.membership_has_module_action(tenant_id, 'customer'::text, 'edit'::text) OR
    ((parent_tenant_id IS
    NOT NULL) AND
    (public.membership_has_module_action(parent_tenant_id, 'recipient_profile'::text, 'edit'::text) OR public.membership_has_module_action(parent_tenant_id, 'customer'::text,
    'edit'::text) OR public.user_can_manage_parent_tenant(parent_tenant_id)))))
  WITH
    CHECK
    ((public.membership_has_module_action(tenant_id, 'recipient_profile'::text, 'edit'::text) OR public.membership_has_module_action(tenant_id, 'customer'::text, 'edit'::text) OR
    ((parent_tenant_id IS
    NOT NULL) AND
    (public.membership_has_module_action(parent_tenant_id, 'recipient_profile'::text, 'edit'::text) OR public.membership_has_module_action(parent_tenant_id, 'customer'::text,
    'edit'::text) OR public.user_can_manage_parent_tenant(parent_tenant_id)))));

ALTER SEQUENCE public.recipient_profiles_id_seq OWNED BY public.recipient_profiles.id;

ALTER TABLE public.recipient_profiles
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.recipient_profiles
  ADD CONSTRAINT recipient_profiles_pkey PRIMARY KEY (id);

ALTER TABLE public.recipient_profiles
  ADD CONSTRAINT recipient_profiles_parent_tenant_id_fkey FOREIGN KEY (parent_tenant_id) REFERENCES public.tenants(id) ON DELETE SET NULL;

ALTER TABLE public.recipient_profiles
  ADD CONSTRAINT recipient_profiles_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE SET NULL;

GRANT ALL ON public.recipient_profiles TO anon;

GRANT ALL ON public.recipient_profiles TO authenticated;

GRANT ALL ON public.recipient_profiles TO service_role;