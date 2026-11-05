CREATE TABLE public.koba_carts (
  id                bigint                   DEFAULT nextval('public.koba_carts_id_seq'::regclass) NOT NULL,
  tenant_id         bigint                   NOT NULL,
  created_at        timestamp with time zone DEFAULT now() NOT NULL,
  updated_at        timestamp with time zone DEFAULT now() NOT NULL,
  customer_group_id bigint
);

CREATE INDEX koba_carts_tenant_idx ON public.koba_carts (tenant_id);

CREATE INDEX koba_carts_customer_group_id_idx ON public.koba_carts (customer_group_id);

CREATE TRIGGER trg_koba_carts_updated_at
  BEFORE UPDATE ON public.koba_carts
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY koba_carts_delete ON public.koba_carts
  FOR DELETE
  TO authenticated
  USING (public.koba_context_access_allowed(tenant_id, customer_group_id));

CREATE POLICY koba_carts_insert ON public.koba_carts
  FOR INSERT
  TO authenticated
  WITH CHECK (public.koba_context_access_allowed(tenant_id, customer_group_id));

CREATE POLICY koba_carts_select ON public.koba_carts
  FOR SELECT
  TO authenticated
  USING (public.koba_context_access_allowed(tenant_id, customer_group_id));

CREATE POLICY koba_carts_update ON public.koba_carts
  FOR UPDATE
  TO authenticated
  USING (public.koba_context_access_allowed(tenant_id, customer_group_id))
  WITH CHECK (public.koba_context_access_allowed(tenant_id, customer_group_id));

COMMENT ON TABLE public.koba_carts IS 'Koba carts scoped by tenant and customer group.';

ALTER SEQUENCE public.koba_carts_id_seq OWNED BY public.koba_carts.id;

ALTER TABLE public.koba_carts
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.koba_carts
  ADD CONSTRAINT koba_carts_customer_group_id_fkey FOREIGN KEY (customer_group_id) REFERENCES public.customer_groups(id) ON DELETE SET NULL;

ALTER TABLE public.koba_carts
  ADD CONSTRAINT koba_carts_pkey PRIMARY KEY (id);

ALTER TABLE public.koba_carts
  ADD CONSTRAINT uq_koba_carts_customer_group UNIQUE (tenant_id, customer_group_id);

ALTER TABLE public.koba_carts
  ADD CONSTRAINT koba_carts_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.koba_carts TO anon;

GRANT ALL ON public.koba_carts TO authenticated;

GRANT ALL ON public.koba_carts TO service_role;