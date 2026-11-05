CREATE TABLE public.koba_brands (
  id         bigint                   DEFAULT nextval('public.koba_brands_id_seq'::regclass) NOT NULL,
  tenant_id  bigint                   NOT NULL,
  name       text                     NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE INDEX koba_brands_tenant_idx ON public.koba_brands (tenant_id);

CREATE TRIGGER trg_koba_brands_updated_at
  BEFORE UPDATE ON public.koba_brands
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY koba_brands_admin_all ON public.koba_brands
  TO authenticated
  USING ((public.is_superadmin() OR public.is_tenant_admin(tenant_id)))
  WITH CHECK ((public.is_superadmin() OR public.is_tenant_admin(tenant_id)));

ALTER SEQUENCE public.koba_brands_id_seq OWNED BY public.koba_brands.id;

ALTER TABLE public.koba_brands
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.koba_brands
  ADD CONSTRAINT koba_brands_pkey PRIMARY KEY (id);

ALTER TABLE public.koba_brands
  ADD CONSTRAINT uq_koba_brands_name UNIQUE (tenant_id, name);

ALTER TABLE public.koba_brands
  ADD CONSTRAINT koba_brands_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.koba_brands TO anon;

GRANT ALL ON public.koba_brands TO authenticated;

GRANT ALL ON public.koba_brands TO service_role;