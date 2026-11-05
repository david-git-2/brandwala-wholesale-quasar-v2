CREATE TABLE public.dropship_order_settlements (
  id                          bigint                            GENERATED ALWAYS AS IDENTITY NOT NULL,
  tenant_id                   bigint                            NOT NULL,
  shop_order_id               bigint                            NOT NULL,
  profile_id                  bigint,
  currency_id                 bigint,
  calculated_cod_amount       numeric(15,2)                     DEFAULT 0 NOT NULL,
  collected_cod_amount        numeric(15,2)                     DEFAULT 0 NOT NULL,
  reseller_purchase_cost      numeric(15,2)                     DEFAULT 0 NOT NULL,
  discount_company_pay        numeric(15,2)                     DEFAULT 0 NOT NULL,
  return_reason_note          text,
  total_cost                  numeric(15,2),
  reseller_profit             numeric(15,2),
  company_profit              numeric(15,2),
  status                      public.dropship_settlement_status DEFAULT 'draft'::public.dropship_settlement_status NOT NULL,
  confirmed_at                timestamp with time zone,
  confirmed_by                uuid,
  courier_cod_booked_at       timestamp with time zone,
  remittance_at               timestamp with time zone,
  merchant_payout_at          timestamp with time zone,
  wallet_ledger_batch_id      text,
  created_at                  timestamp with time zone          DEFAULT now() NOT NULL,
  updated_at                  timestamp with time zone          DEFAULT now() NOT NULL,
  reseller_unit_purchase_cost numeric(15,2)                     DEFAULT 0 NOT NULL
);

CREATE INDEX idx_dropship_order_settlements_tenant ON public.dropship_order_settlements (tenant_id);

CREATE TRIGGER trg_dropship_order_settlements_set_updated_at
  BEFORE UPDATE ON public.dropship_order_settlements
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY dropship_order_settlements_staff_all ON public.dropship_order_settlements
  USING (public.is_tenant_staff(tenant_id))
  WITH CHECK (public.is_tenant_staff(tenant_id));

ALTER TABLE public.dropship_order_settlements
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.dropship_order_settlements
  ADD CONSTRAINT dropship_order_settlements_pkey PRIMARY KEY (id);

ALTER TABLE public.dropship_order_settlements
  ADD CONSTRAINT dropship_order_settlements_shop_order_id_key UNIQUE (shop_order_id);

ALTER TABLE public.dropship_order_settlements
  ADD CONSTRAINT dropship_order_settlements_currency_id_fkey FOREIGN KEY (currency_id) REFERENCES public.global_currencies(id) ON DELETE SET NULL;

ALTER TABLE public.dropship_order_settlements
  ADD CONSTRAINT dropship_order_settlements_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id) ON DELETE SET NULL;

ALTER TABLE public.dropship_order_settlements
  ADD CONSTRAINT dropship_order_settlements_shop_order_id_fkey FOREIGN KEY (shop_order_id) REFERENCES public.shop_orders(id) ON DELETE CASCADE;

ALTER TABLE public.dropship_order_settlements
  ADD CONSTRAINT dropship_order_settlements_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.dropship_order_settlements TO anon;

GRANT ALL ON public.dropship_order_settlements TO authenticated;

GRANT ALL ON public.dropship_order_settlements TO service_role;