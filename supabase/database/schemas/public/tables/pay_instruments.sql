CREATE TABLE public.pay_instruments (
  id                  bigint                   DEFAULT nextval('public.global_payment_instruments_id_seq'::regclass) NOT NULL,
  payment_id          bigint                   NOT NULL,
  payment_method_code text                     NOT NULL,
  amount              numeric(12,2)            NOT NULL,
  reference           text,
  bd_bank_id          bigint,
  cheque_number       text,
  cheque_date         date,
  sort_order          integer                  DEFAULT 0 NOT NULL,
  created_at          timestamp with time zone DEFAULT now() NOT NULL,
  cashbook_point_id   bigint,
  bounced_at          timestamp with time zone
);

CREATE INDEX global_payment_instruments_payment_id_idx ON public.pay_instruments (payment_id);

CREATE INDEX global_payment_instruments_method_code_idx ON public.pay_instruments (payment_method_code);

CREATE POLICY superadmin_can_manage_global_payment_instruments ON public.pay_instruments
  TO authenticated
  USING (public.is_superadmin())
  WITH CHECK (public.is_superadmin());

ALTER SEQUENCE public.global_payment_instruments_id_seq OWNED BY public.pay_instruments.id;

ALTER TABLE public.pay_instruments
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.pay_instruments
  ADD CONSTRAINT global_payment_instruments_amount_positive CHECK (amount > 0::numeric);

ALTER TABLE public.pay_instruments
  ADD CONSTRAINT global_payment_instruments_bd_bank_id_fkey FOREIGN KEY (bd_bank_id) REFERENCES public.bd_banks(id);

ALTER TABLE public.pay_instruments
  ADD CONSTRAINT global_payment_instruments_cheque_fields CHECK (payment_method_code <> 'CHEQUE'::text OR bd_bank_id IS
    NOT NULL AND NULLIF(TRIM(BOTH FROM cheque_number), ''::text) IS NOT NULL AND cheque_date IS NOT NULL);

ALTER TABLE public.pay_instruments
  ADD CONSTRAINT global_payment_instruments_pkey PRIMARY KEY (id);

ALTER TABLE public.pay_instruments
  ADD CONSTRAINT pay_instruments_cashbook_point_id_fkey FOREIGN KEY (cashbook_point_id) REFERENCES public.cashbook_points(id) ON DELETE SET NULL;

ALTER TABLE public.pay_instruments
  ADD CONSTRAINT global_payment_instruments_payment_method_code_fkey FOREIGN KEY (payment_method_code) REFERENCES public.payment_methods(code);

ALTER TABLE public.pay_instruments
  ADD CONSTRAINT global_payment_instruments_payment_id_fkey FOREIGN KEY (payment_id) REFERENCES public.pays(id) ON DELETE CASCADE;

GRANT ALL ON public.pay_instruments TO anon;

GRANT ALL ON public.pay_instruments TO authenticated;

GRANT ALL ON public.pay_instruments TO service_role;