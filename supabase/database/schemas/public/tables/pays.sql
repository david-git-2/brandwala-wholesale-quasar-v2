CREATE TABLE public.pays (
  id                       bigint                        DEFAULT nextval('public.payments_id_seq'::regclass) NOT NULL,
  tenant_id                bigint                        NOT NULL,
  amount                   numeric(12,2)                 NOT NULL,
  payment_date             date                          DEFAULT CURRENT_DATE NOT NULL,
  method                   text,
  reference                text,
  note                     text,
  created_at               timestamp with time zone      DEFAULT now() NOT NULL,
  unallocated_amount       numeric(12,2)                 DEFAULT 0.00 NOT NULL,
  collection_source        public.collection_source_type DEFAULT 'billing_profile'::public.collection_source_type NOT NULL,
  customer_group_id        bigint,
  voided_at                timestamp with time zone,
  shop_order_id            bigint,
  profile_id               bigint,
  source                   text                          DEFAULT 'customer_cash'::text NOT NULL,
  settlement_currency_code text                          DEFAULT 'BDT'::text NOT NULL,
  foreign_amount           numeric(12,2),
  exchange_rate            numeric(15,6)                 DEFAULT 1.000000 NOT NULL,
  cashbook_point_id        bigint,
  quote_currency_code      text                          DEFAULT 'BDT'::text NOT NULL,
  source_currency_code     text,
  transaction_rate         numeric(15,6),
  source_amount            numeric(12,2),
  cashbook_point_pot_id    bigint,
  idempotency_key          text
);

CREATE INDEX pays_cashbook_point_id_idx ON public.pays (cashbook_point_id)
  WHERE cashbook_point_id IS NOT NULL;

CREATE INDEX global_payments_voided_at_idx ON public.pays (voided_at)
  WHERE voided_at IS NOT NULL;

CREATE INDEX idx_global_payments_customer_group_id ON public.pays (customer_group_id);

CREATE INDEX idx_global_payments_shop_order_id ON public.pays (shop_order_id)
  WHERE shop_order_id IS NOT NULL;

CREATE INDEX payments_payment_date_idx ON public.pays (payment_date);

CREATE INDEX payments_tenant_id_idx ON public.pays (tenant_id);

CREATE INDEX pays_profile_id_idx ON public.pays (profile_id);

CREATE UNIQUE INDEX pays_tenant_idempotency_uidx ON public.pays (tenant_id, idempotency_key)
  WHERE idempotency_key IS NOT NULL;

CREATE POLICY payments_delete ON public.pays
  FOR DELETE
  TO authenticated
  USING (public.membership_has_module_action(tenant_id, 'payments'::text, 'void'::text));

CREATE POLICY payments_insert ON public.pays
  FOR INSERT
  TO authenticated
  WITH CHECK (public.membership_has_module_action(tenant_id, 'payments'::text, 'collect_payment'::text));

CREATE POLICY payments_select ON public.pays
  FOR SELECT
  TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE ((m.tenant_id = pays.tenant_id) AND (lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.is_active = true)))));

CREATE POLICY payments_update ON public.pays
  FOR UPDATE
  TO authenticated
  USING (public.membership_has_module_action(tenant_id, 'payments'::text, 'allocate_payment'::text))
  WITH CHECK (public.membership_has_module_action(tenant_id, 'payments'::text, 'allocate_payment'::text));

ALTER SEQUENCE public.payments_id_seq OWNED BY public.pays.id;

ALTER TABLE public.pays
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.pays
  ADD CONSTRAINT global_payments_customer_group_id_fkey FOREIGN KEY (customer_group_id) REFERENCES public.customer_groups(id) ON DELETE SET NULL;

ALTER TABLE public.pays
  ADD CONSTRAINT payments_amount_check CHECK (amount >= 0::numeric);

ALTER TABLE public.pays
  ADD CONSTRAINT payments_method_check
    CHECK
    (method IS NULL OR (method = ANY (ARRAY['cash'::text, 'bank'::text, 'bank_transfer'::text, 'mobile_banking'::text, 'bkash'::text, 'nagad'::text, 'other'::text, 'cheque'::text,
    'rocket'::text,
    'upay'::text,
    'tap'::text, 'card_pos'::text, 'wire_transfer'::text, 'paypal'::text, 'stripe'::text, 'letter_of_credit'::text, 'cod'::text, 'split'::text, 'store_credit'::text])));

ALTER TABLE public.pays
  ADD CONSTRAINT payments_pkey PRIMARY KEY (id);

ALTER TABLE public.pays
  ADD CONSTRAINT pays_cashbook_point_id_fkey FOREIGN KEY (cashbook_point_id) REFERENCES public.cashbook_points(id) ON DELETE SET NULL;

ALTER TABLE public.pays
  ADD CONSTRAINT pays_cashbook_point_pot_id_fkey FOREIGN KEY (cashbook_point_pot_id) REFERENCES public.cashbook_point_pots(id) ON DELETE SET NULL;

ALTER TABLE public.pays
  ADD CONSTRAINT pays_exchange_rate_positive CHECK (exchange_rate > 0::numeric);

ALTER TABLE public.pays
  ADD CONSTRAINT pays_settlement_fx_check
    CHECK (settlement_currency_code = 'BDT'::text AND foreign_amount IS NULL AND exchange_rate = 1.000000 OR settlement_currency_code <> 'BDT'::text AND foreign_amount IS
    NOT NULL AND foreign_amount > 0::numeric AND exchange_rate > 0::numeric);

ALTER TABLE public.pays
  ADD CONSTRAINT pays_source_check
    CHECK (source = ANY (ARRAY['customer_cash'::text, 'bank'::text, 'store_credit'::text, 'courier_remittance'::text, 'ap_payout'::text, 'commission'::text]));

ALTER TABLE public.pays
  ADD CONSTRAINT pays_source_fx_check CHECK (source_currency_code IS NULL AND transaction_rate IS NULL AND source_amount IS NULL OR source_currency_code IS
    NOT NULL AND btrim(source_currency_code) <> ''::text AND
    (upper(source_currency_code) = upper(settlement_currency_code) AND (transaction_rate IS NULL OR transaction_rate = 1.000000) OR upper(source_currency_code) <>
    upper(settlement_currency_code) AND transaction_rate > 0::numeric));

ALTER TABLE public.pays
  ADD CONSTRAINT pays_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id) ON DELETE SET NULL;

ALTER TABLE public.pays
  ADD CONSTRAINT global_payments_shop_order_id_fkey FOREIGN KEY (shop_order_id) REFERENCES public.shop_orders(id) ON DELETE SET NULL;

ALTER TABLE public.pays
  ADD CONSTRAINT payments_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.pays TO anon;

GRANT ALL ON public.pays TO authenticated;

GRANT ALL ON public.pays TO service_role;