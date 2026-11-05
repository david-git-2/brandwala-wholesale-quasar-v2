CREATE TABLE public.pay_allocations (
  id                  bigint                   DEFAULT nextval('public.payment_allocations_id_seq'::regclass) NOT NULL,
  tenant_id           bigint                   NOT NULL,
  payment_id          bigint                   NOT NULL,
  invoice_id          bigint,
  amount              numeric(12,2)            NOT NULL,
  created_at          timestamp with time zone DEFAULT now() NOT NULL,
  global_invoice_id   bigint,
  commerce_invoice_id bigint,
  bill_id             bigint
);

CREATE INDEX payment_allocations_commerce_invoice_id_idx ON public.pay_allocations (commerce_invoice_id);

CREATE INDEX payment_allocations_tenant_id_idx ON public.pay_allocations (tenant_id);

CREATE INDEX pay_allocations_bill_id_idx ON public.pay_allocations (bill_id);

CREATE INDEX payment_allocations_payment_id_idx ON public.pay_allocations (payment_id);

CREATE INDEX payment_allocations_invoice_id_idx ON public.pay_allocations (invoice_id);

CREATE INDEX payment_allocations_global_invoice_id_idx ON public.pay_allocations (global_invoice_id);

CREATE POLICY payment_allocations_select ON public.pay_allocations
  FOR SELECT
  TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE ((m.tenant_id = pay_allocations.tenant_id) AND (lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.is_active = true)))));

CREATE POLICY payment_allocations_delete ON public.pay_allocations
  FOR DELETE
  TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM public.pays p
  WHERE ((p.id = pay_allocations.payment_id) AND public.membership_has_module_action(p.tenant_id, 'payments'::text, 'void'::text)))));

CREATE POLICY payment_allocations_insert ON public.pay_allocations
  FOR INSERT
  TO authenticated
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.pays p
  WHERE ((p.id = pay_allocations.payment_id) AND public.membership_has_module_action(p.tenant_id, 'payments'::text, 'allocate_payment'::text)))));

CREATE POLICY payment_allocations_update ON public.pay_allocations
  FOR UPDATE
  TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM public.pays p
  WHERE ((p.id = pay_allocations.payment_id) AND public.membership_has_module_action(p.tenant_id, 'payments'::text, 'allocate_payment'::text)))))
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.pays p
  WHERE ((p.id = pay_allocations.payment_id) AND public.membership_has_module_action(p.tenant_id, 'payments'::text, 'allocate_payment'::text)))));

ALTER SEQUENCE public.payment_allocations_id_seq OWNED BY public.pay_allocations.id;

ALTER TABLE public.pay_allocations
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.pay_allocations
  ADD CONSTRAINT pay_allocations_bill_id_fkey FOREIGN KEY (bill_id) REFERENCES public.bills(id) ON DELETE CASCADE;

ALTER TABLE public.pay_allocations
  ADD CONSTRAINT payment_allocations_amount_check CHECK (amount > 0::numeric);

ALTER TABLE public.pay_allocations
  ADD CONSTRAINT payment_allocations_global_invoice_id_fkey FOREIGN KEY (global_invoice_id) REFERENCES public.bills(id) ON DELETE CASCADE;

ALTER TABLE public.pay_allocations
  ADD CONSTRAINT payment_allocations_pkey PRIMARY KEY (id);

ALTER TABLE public.pay_allocations
  ADD CONSTRAINT payment_allocations_payment_id_fkey FOREIGN KEY (payment_id) REFERENCES public.pays(id) ON DELETE CASCADE;

ALTER TABLE public.pay_allocations
  ADD CONSTRAINT payment_allocations_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.pay_allocations TO anon;

GRANT ALL ON public.pay_allocations TO authenticated;

GRANT ALL ON public.pay_allocations TO service_role;