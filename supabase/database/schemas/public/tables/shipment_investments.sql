CREATE TABLE public.shipment_investments (
  id                 bigint                            DEFAULT nextval('public.shipment_investments_id_seq'::regclass) NOT NULL,
  tenant_id          bigint                            NOT NULL,
  investor_id        bigint                            NOT NULL,
  invested_amount    numeric(12,2)                     DEFAULT 0 NOT NULL,
  actual_profit      numeric(12,2)                     DEFAULT 0 NOT NULL,
  status             public.shipment_investment_status DEFAULT 'active'::public.shipment_investment_status NOT NULL,
  created_at         timestamp with time zone          DEFAULT now() NOT NULL,
  updated_at         timestamp with time zone          DEFAULT now() NOT NULL,
  cost_share_pct     numeric(5,2),
  allocated_cost     numeric(12,2)                     DEFAULT 0 NOT NULL,
  computed_profit    numeric(12,2)                     DEFAULT 0 NOT NULL,
  profit_status      text                              DEFAULT 'open'::text NOT NULL,
  global_shipment_id bigint                            NOT NULL
);

CREATE UNIQUE INDEX shipment_investments_tenant_investor_global_shipment_key ON public.shipment_investments (tenant_id, investor_id, global_shipment_id);

CREATE INDEX shipment_investments_tenant_id_idx ON public.shipment_investments (tenant_id);

CREATE INDEX shipment_investments_global_shipment_id_idx ON public.shipment_investments (global_shipment_id);

CREATE INDEX shipment_investments_investor_id_idx ON public.shipment_investments (investor_id);

CREATE TRIGGER trg_shipment_investments_set_updated_at
  BEFORE UPDATE ON public.shipment_investments
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY shipment_investments_delete ON public.shipment_investments
  FOR DELETE
  TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE
    ((m.tenant_id = shipment_investments.tenant_id) AND (lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.is_active = true) AND (m.role = ANY
    (ARRAY['admin'::public.app_role, 'staff'::public.app_role]))))));

CREATE POLICY shipment_investments_insert ON public.shipment_investments
  FOR INSERT
  TO authenticated
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE
    ((m.tenant_id = shipment_investments.tenant_id) AND (lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.is_active = true) AND (m.role = ANY
    (ARRAY['admin'::public.app_role, 'staff'::public.app_role]))))));

CREATE POLICY shipment_investments_select ON public.shipment_investments
  FOR SELECT
  TO authenticated
  USING ((public.investor_tenant_can_view(tenant_id) OR (public.auth_investor_id() = investor_id)));

CREATE POLICY shipment_investments_update ON public.shipment_investments
  FOR UPDATE
  TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE
    ((m.tenant_id = shipment_investments.tenant_id) AND (lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.is_active = true) AND (m.role = ANY
    (ARRAY['admin'::public.app_role, 'staff'::public.app_role]))))))
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE
    ((m.tenant_id = shipment_investments.tenant_id) AND (lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.is_active = true) AND (m.role = ANY
    (ARRAY['admin'::public.app_role, 'staff'::public.app_role]))))));

ALTER SEQUENCE public.shipment_investments_id_seq OWNED BY public.shipment_investments.id;

ALTER TABLE public.shipment_investments
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.shipment_investments
  ADD CONSTRAINT shipment_investments_cost_share_pct_check CHECK (cost_share_pct IS NULL OR cost_share_pct >= 0::numeric AND cost_share_pct <= 100::numeric);

ALTER TABLE public.shipment_investments
  ADD CONSTRAINT shipment_investments_global_shipment_id_fkey FOREIGN KEY (global_shipment_id) REFERENCES public.global_shipments(id) ON DELETE CASCADE;

ALTER TABLE public.shipment_investments
  ADD CONSTRAINT shipment_investments_invested_amount_check CHECK (invested_amount >= 0::numeric);

ALTER TABLE public.shipment_investments
  ADD CONSTRAINT shipment_investments_investor_id_fkey FOREIGN KEY (investor_id) REFERENCES public.investors(id) ON DELETE CASCADE;

ALTER TABLE public.shipment_investments
  ADD CONSTRAINT shipment_investments_pkey PRIMARY KEY (id);

ALTER TABLE public.shipment_investments
  ADD CONSTRAINT shipment_investments_profit_status_check CHECK (profit_status = ANY (ARRAY['open'::text, 'partial'::text, 'realized'::text]));

ALTER TABLE public.shipment_investments
  ADD CONSTRAINT shipment_investments_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.shipment_investments TO anon;

GRANT ALL ON public.shipment_investments TO authenticated;

GRANT ALL ON public.shipment_investments TO service_role;