CREATE TABLE public.courier_remittance_batches (
  id                     bigint                   GENERATED ALWAYS AS IDENTITY NOT NULL,
  tenant_id              bigint                   NOT NULL,
  courier_service_id     uuid                     NOT NULL,
  batch_no               text                     NOT NULL,
  bank_trx_id            text,
  payment_date           date                     DEFAULT CURRENT_DATE NOT NULL,
  gross_cod_amount       numeric(12,2)            DEFAULT 0.00 NOT NULL,
  courier_charges_amount numeric(12,2)            DEFAULT 0.00 NOT NULL,
  net_deposited_amount   numeric(12,2)            DEFAULT 0.00 NOT NULL,
  allocated_amount       numeric(12,2)            DEFAULT 0.00 NOT NULL,
  variance_amount        numeric(12,2)            DEFAULT 0.00 NOT NULL,
  status                 text                     DEFAULT 'draft'::text NOT NULL,
  note                   text,
  created_by             uuid,
  created_at             timestamp with time zone DEFAULT now() NOT NULL,
  updated_at             timestamp with time zone DEFAULT now() NOT NULL,
  posted_at              timestamp with time zone,
  posted_by              uuid
);

CREATE INDEX idx_courier_remittance_batches_tenant ON public.courier_remittance_batches (tenant_id);

CREATE INDEX idx_courier_remittance_batches_status ON public.courier_remittance_batches (tenant_id, status);

CREATE INDEX idx_courier_remittance_batches_courier ON public.courier_remittance_batches (courier_service_id);

CREATE POLICY courier_remittance_batches_tenant_isolation ON public.courier_remittance_batches
  TO authenticated
  USING ((public.is_superadmin() OR (EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE ((m.tenant_id = courier_remittance_batches.tenant_id) AND (lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.is_active = true))))))
  WITH CHECK ((public.is_superadmin() OR (EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE ((m.tenant_id = courier_remittance_batches.tenant_id) AND (lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.is_active = true))))));

ALTER TABLE public.courier_remittance_batches
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.courier_remittance_batches
  ADD CONSTRAINT courier_remittance_batches_allocated_amount_check CHECK (allocated_amount >= 0::numeric);

ALTER TABLE public.courier_remittance_batches
  ADD CONSTRAINT courier_remittance_batches_courier_charges_amount_check CHECK (courier_charges_amount >= 0::numeric);

ALTER TABLE public.courier_remittance_batches
  ADD CONSTRAINT courier_remittance_batches_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.courier_remittance_batches
  ADD CONSTRAINT courier_remittance_batches_gross_cod_amount_check CHECK (gross_cod_amount >= 0::numeric);

ALTER TABLE public.courier_remittance_batches
  ADD CONSTRAINT courier_remittance_batches_net_deposited_amount_check CHECK (net_deposited_amount >= 0::numeric);

ALTER TABLE public.courier_remittance_batches
  ADD CONSTRAINT courier_remittance_batches_pkey PRIMARY KEY (id);

ALTER TABLE public.courier_remittance_batches
  ADD CONSTRAINT courier_remittance_batches_posted_by_fkey FOREIGN KEY (posted_by) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.courier_remittance_batches
  ADD CONSTRAINT courier_remittance_batches_status_check CHECK (status = ANY (ARRAY['draft'::text, 'posted'::text, 'voided'::text]));

ALTER TABLE public.courier_remittance_batches
  ADD CONSTRAINT uq_tenant_courier_batch_no UNIQUE (tenant_id, courier_service_id, batch_no);

ALTER TABLE public.courier_remittance_batches
  ADD CONSTRAINT courier_remittance_batches_courier_service_id_fkey FOREIGN KEY (courier_service_id) REFERENCES public.courier_services(id) ON DELETE RESTRICT;

ALTER TABLE public.courier_remittance_batches
  ADD CONSTRAINT courier_remittance_batches_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.courier_remittance_batches TO anon;

GRANT ALL ON public.courier_remittance_batches TO authenticated;

GRANT ALL ON public.courier_remittance_batches TO service_role;