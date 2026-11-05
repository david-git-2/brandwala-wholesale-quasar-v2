CREATE TABLE public.thrift_categories (
  id          bigint                   DEFAULT nextval('public.thrift_categories_id_seq'::regclass) NOT NULL,
  tenant_id   bigint,
  name        text                     NOT NULL,
  description text,
  inserted_by text                     NOT NULL,
  created_at  timestamp with time zone DEFAULT now() NOT NULL,
  updated_at  timestamp with time zone DEFAULT now() NOT NULL,
  is_global   boolean                  DEFAULT false NOT NULL
);

CREATE UNIQUE INDEX thrift_categories_global_name_unique ON public.thrift_categories (name)
  WHERE is_global = true;

CREATE UNIQUE INDEX thrift_categories_tenant_name_unique ON public.thrift_categories (tenant_id, name)
  WHERE is_global = false;

CREATE TRIGGER trg_thrift_categories_updated_at
  BEFORE UPDATE ON public.thrift_categories
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY select_thrift_categories ON public.thrift_categories
  FOR SELECT
  TO authenticated
  USING (((is_global = true) OR (EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE ((m.tenant_id = thrift_categories.tenant_id) AND (lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.is_active = true))))));

CREATE POLICY write_thrift_categories ON public.thrift_categories
  TO authenticated
  USING (public.membership_has_module_action(tenant_id, 'thrift_category'::text, 'edit'::text));

ALTER SEQUENCE public.thrift_categories_id_seq OWNED BY public.thrift_categories.id;

ALTER TABLE public.thrift_categories
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.thrift_categories
  ADD CONSTRAINT thrift_categories_pkey PRIMARY KEY (id);

ALTER TABLE public.thrift_categories
  ADD CONSTRAINT thrift_categories_scope_check CHECK (is_global = true AND tenant_id IS NULL OR is_global = false AND tenant_id IS NOT NULL);

ALTER TABLE public.thrift_categories
  ADD CONSTRAINT thrift_categories_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.thrift_categories TO anon;

GRANT ALL ON public.thrift_categories TO authenticated;

GRANT ALL ON public.thrift_categories TO service_role;