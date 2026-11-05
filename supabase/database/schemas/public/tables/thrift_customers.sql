CREATE TABLE public.thrift_customers (
  id               bigint                   DEFAULT nextval('public.thrift_customers_id_seq'::regclass) NOT NULL,
  tenant_id        bigint                   NOT NULL,
  name             text                     NOT NULL,
  phone            text                     NOT NULL,
  phone_normalized text                     NOT NULL,
  address          text,
  notes            text,
  inserted_by      text                     NOT NULL,
  created_at       timestamp with time zone DEFAULT now() NOT NULL,
  updated_at       timestamp with time zone DEFAULT now() NOT NULL,
  secondary_phone  text,
  address_parts    jsonb                    DEFAULT '{}'::jsonb NOT NULL
);

CREATE INDEX idx_thrift_customers_tenant_name ON public.thrift_customers (tenant_id, name);

CREATE INDEX idx_thrift_customers_tenant_updated ON public.thrift_customers (tenant_id, updated_at DESC);

CREATE TRIGGER trg_thrift_customers_updated_at
  BEFORE UPDATE ON public.thrift_customers
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY select_thrift_customers ON public.thrift_customers
  FOR SELECT
  TO authenticated
  USING
    ((public.membership_has_module_action(tenant_id, 'thrift_customers'::text, 'view'::text) OR public.membership_has_module_action(tenant_id, 'thrift_sales'::text, 'view'::text)));

CREATE POLICY write_thrift_customers ON public.thrift_customers
  TO authenticated
  USING (public.membership_has_module_action(tenant_id, 'thrift_sales'::text, 'edit'::text))
  WITH CHECK (public.membership_has_module_action(tenant_id, 'thrift_sales'::text, 'edit'::text));

COMMENT ON COLUMN public.thrift_customers.secondary_phone IS 'Optional alternate phone (not unique; primary phone_normalized remains upsert key).';

COMMENT ON COLUMN public.thrift_customers.address_parts IS 'BD location parts from static district/thana/postcode catalogs: { district, thana, post_code }. Freeform street stays in address.';

ALTER SEQUENCE public.thrift_customers_id_seq OWNED BY public.thrift_customers.id;

ALTER TABLE public.thrift_customers
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.thrift_customers
  ADD CONSTRAINT thrift_customers_phone_normalized_match_check CHECK (phone_normalized <> ''::text AND phone_normalized = public.normalize_thrift_phone(phone));

ALTER TABLE public.thrift_customers
  ADD CONSTRAINT thrift_customers_pkey PRIMARY KEY (id);

ALTER TABLE public.thrift_customers
  ADD CONSTRAINT thrift_customers_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

ALTER TABLE public.thrift_customers
  ADD CONSTRAINT thrift_customers_tenant_phone_normalized_key UNIQUE (tenant_id, phone_normalized);

GRANT ALL ON public.thrift_customers TO anon;

GRANT ALL ON public.thrift_customers TO authenticated;

GRANT ALL ON public.thrift_customers TO service_role;