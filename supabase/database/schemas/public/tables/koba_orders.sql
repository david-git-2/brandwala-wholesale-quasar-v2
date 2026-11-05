CREATE TABLE public.koba_orders (
  id                   bigint                   DEFAULT nextval('public.koba_orders_id_seq'::regclass) NOT NULL,
  tenant_id            bigint                   NOT NULL,
  user_name            text,
  shipping_name        text,
  shipping_phone       text,
  shipping_district    text,
  shipping_thana       text,
  shipping_address     text,
  free_delivery        boolean                  DEFAULT false NOT NULL,
  subtotal_gbp         numeric(12,2),
  total_commission     numeric(12,2),
  item_count           integer                  DEFAULT 0 NOT NULL,
  status               public.koba_order_status DEFAULT 'pending'::public.koba_order_status NOT NULL,
  note                 text,
  created_at           timestamp with time zone DEFAULT now() NOT NULL,
  updated_at           timestamp with time zone DEFAULT now() NOT NULL,
  customer_group_id    bigint,
  extra_profit_user    numeric(12,2)            DEFAULT 0,
  extra_profit_company numeric(12,2)            DEFAULT 0,
  delivery_adjustment  numeric(12,2)            DEFAULT 0,
  cod_charge           numeric(12,2)            DEFAULT 0,
  packing_charge       numeric(12,2)            DEFAULT 0,
  invoice_charge       numeric(12,2)            DEFAULT 0,
  net_order_commission numeric(12,2)            DEFAULT 0
);

CREATE INDEX koba_orders_status_idx ON public.koba_orders (status);

CREATE INDEX koba_orders_tenant_phone_idx ON public.koba_orders (tenant_id, shipping_phone)
  WHERE shipping_phone IS NOT NULL AND shipping_phone <> ''::text;

CREATE INDEX koba_orders_tenant_idx ON public.koba_orders (tenant_id);

CREATE INDEX koba_orders_customer_group_id_idx ON public.koba_orders (customer_group_id);

CREATE TRIGGER trg_koba_orders_updated_at
  BEFORE UPDATE ON public.koba_orders
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY koba_orders_delete ON public.koba_orders
  FOR DELETE
  TO authenticated
  USING ((public.is_superadmin() OR public.is_tenant_admin(tenant_id)));

CREATE POLICY koba_orders_insert ON public.koba_orders
  FOR INSERT
  TO authenticated
  WITH CHECK (public.koba_context_access_allowed(tenant_id, customer_group_id));

CREATE POLICY koba_orders_select ON public.koba_orders
  FOR SELECT
  TO authenticated
  USING (public.koba_context_access_allowed(tenant_id, customer_group_id));

CREATE POLICY koba_orders_update ON public.koba_orders
  FOR UPDATE
  TO authenticated
  USING (public.koba_context_access_allowed(tenant_id, customer_group_id))
  WITH CHECK (public.koba_context_access_allowed(tenant_id, customer_group_id));

COMMENT ON TABLE public.koba_orders IS 'Koba orders scoped by tenant and customer group.';

ALTER SEQUENCE public.koba_orders_id_seq OWNED BY public.koba_orders.id;

ALTER TABLE public.koba_orders
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.koba_orders
  ADD CONSTRAINT koba_orders_customer_group_id_fkey FOREIGN KEY (customer_group_id) REFERENCES public.customer_groups(id) ON DELETE SET NULL;

ALTER TABLE public.koba_orders
  ADD CONSTRAINT koba_orders_pkey PRIMARY KEY (id);

ALTER TABLE public.koba_orders
  ADD CONSTRAINT koba_orders_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.koba_orders TO anon;

GRANT ALL ON public.koba_orders TO authenticated;

GRANT ALL ON public.koba_orders TO service_role;