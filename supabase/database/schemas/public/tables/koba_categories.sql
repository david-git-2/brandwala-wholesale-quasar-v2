CREATE TABLE public.koba_categories (
  id         bigint                   DEFAULT nextval('public.koba_categories_id_seq'::regclass) NOT NULL,
  tenant_id  bigint                   NOT NULL,
  name       text                     NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE INDEX koba_categories_tenant_idx ON public.koba_categories (tenant_id);

CREATE TRIGGER trg_koba_categories_updated_at
  BEFORE UPDATE ON public.koba_categories
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY koba_categories_admin_all ON public.koba_categories
  TO authenticated
  USING ((public.is_superadmin() OR public.is_tenant_admin(tenant_id)))
  WITH CHECK ((public.is_superadmin() OR public.is_tenant_admin(tenant_id)));

ALTER SEQUENCE public.koba_categories_id_seq OWNED BY public.koba_categories.id;

ALTER TABLE public.koba_categories
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.koba_categories
  ADD CONSTRAINT koba_categories_pkey PRIMARY KEY (id);

ALTER TABLE public.koba_categories
  ADD CONSTRAINT uq_koba_categories_name UNIQUE (tenant_id, name);

ALTER TABLE public.koba_categories
  ADD CONSTRAINT koba_categories_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.koba_categories TO anon;

GRANT ALL ON public.koba_categories TO authenticated;

GRANT ALL ON public.koba_categories TO service_role;