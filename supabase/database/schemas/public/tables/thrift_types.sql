CREATE TABLE public.thrift_types (
  id          bigint                   DEFAULT nextval('public.thrift_types_id_seq'::regclass) NOT NULL,
  tenant_id   bigint,
  name        text                     NOT NULL,
  description text,
  inserted_by text                     NOT NULL,
  created_at  timestamp with time zone DEFAULT now() NOT NULL,
  updated_at  timestamp with time zone DEFAULT now() NOT NULL,
  is_global   boolean                  DEFAULT false NOT NULL,
  icon        text
);

CREATE UNIQUE INDEX thrift_types_global_name_unique ON public.thrift_types (name)
  WHERE is_global = true;

CREATE UNIQUE INDEX thrift_types_tenant_name_unique ON public.thrift_types (tenant_id, name)
  WHERE is_global = false;

CREATE TRIGGER trg_thrift_types_updated_at
  BEFORE UPDATE ON public.thrift_types
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY select_thrift_types ON public.thrift_types
  FOR SELECT
  TO authenticated
  USING (((is_global = true) OR (EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE ((m.tenant_id = thrift_types.tenant_id) AND (lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.is_active = true))))));

CREATE POLICY write_thrift_types ON public.thrift_types
  TO authenticated
  USING (public.membership_has_module_action(tenant_id, 'thrift_type'::text, 'edit'::text));

ALTER SEQUENCE public.thrift_types_id_seq OWNED BY public.thrift_types.id;

ALTER TABLE public.thrift_types
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.thrift_types
  ADD CONSTRAINT thrift_types_pkey PRIMARY KEY (id);

ALTER TABLE public.thrift_types
  ADD CONSTRAINT thrift_types_scope_check CHECK (is_global = true AND tenant_id IS NULL OR is_global = false AND tenant_id IS NOT NULL);

ALTER TABLE public.thrift_types
  ADD CONSTRAINT thrift_types_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.thrift_types TO anon;

GRANT ALL ON public.thrift_types TO authenticated;

GRANT ALL ON public.thrift_types TO service_role;