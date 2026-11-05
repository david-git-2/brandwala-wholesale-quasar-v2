CREATE TABLE public.invoice_write_offs (
  id               bigint                   GENERATED ALWAYS AS IDENTITY NOT NULL,
  tenant_id        bigint                   NOT NULL,
  parent_tenant_id bigint                   NOT NULL,
  invoice_id       bigint                   NOT NULL,
  payment_id       bigint,
  amount           numeric(12,2)            NOT NULL,
  reason           text                     NOT NULL,
  note             text,
  approved_by      uuid,
  created_at       timestamp with time zone DEFAULT now() NOT NULL
);

CREATE INDEX idx_invoice_write_offs_invoice_id ON public.invoice_write_offs (invoice_id);

CREATE INDEX idx_invoice_write_offs_parent_tenant_id ON public.invoice_write_offs (parent_tenant_id);

CREATE INDEX idx_invoice_write_offs_payment_id ON public.invoice_write_offs (payment_id);

CREATE INDEX idx_invoice_write_offs_tenant_id ON public.invoice_write_offs (tenant_id);

CREATE POLICY invoice_write_offs_write ON public.invoice_write_offs
  TO authenticated
  USING
    ((public.membership_has_module_action(parent_tenant_id, 'global_invoice'::text, 'edit'::text) OR public.membership_has_module_action(tenant_id, 'global_invoice'::text,
    'edit'::text)))
  WITH
    CHECK
    ((public.membership_has_module_action(parent_tenant_id, 'global_invoice'::text, 'edit'::text) OR public.membership_has_module_action(tenant_id, 'global_invoice'::text,
    'edit'::text)));

CREATE POLICY invoice_write_offs_select ON public.invoice_write_offs
  FOR SELECT
  TO authenticated
  USING (((EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE ((m.tenant_id = invoice_write_offs.parent_tenant_id) AND (lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.is_active = true)))) OR (EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE ((m.tenant_id = invoice_write_offs.tenant_id) AND (lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.is_active = true))))));

ALTER TABLE public.invoice_write_offs
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.invoice_write_offs
  ADD CONSTRAINT invoice_write_offs_amount_check CHECK (amount > 0::numeric);

ALTER TABLE public.invoice_write_offs
  ADD CONSTRAINT invoice_write_offs_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES auth.users(id);

ALTER TABLE public.invoice_write_offs
  ADD CONSTRAINT invoice_write_offs_invoice_id_fkey FOREIGN KEY (invoice_id) REFERENCES public.bills(id) ON DELETE CASCADE;

ALTER TABLE public.invoice_write_offs
  ADD CONSTRAINT invoice_write_offs_pkey PRIMARY KEY (id);

ALTER TABLE public.invoice_write_offs
  ADD CONSTRAINT invoice_write_offs_reason_check
    CHECK (reason = ANY (ARRAY['dispute_settlement'::text, 'bad_debt'::text, 'currency_rounding'::text, 'management_concession'::text]));

ALTER TABLE public.invoice_write_offs
  ADD CONSTRAINT invoice_write_offs_payment_id_fkey FOREIGN KEY (payment_id) REFERENCES public.pays(id) ON DELETE SET NULL;

ALTER TABLE public.invoice_write_offs
  ADD CONSTRAINT invoice_write_offs_parent_tenant_id_fkey FOREIGN KEY (parent_tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

ALTER TABLE public.invoice_write_offs
  ADD CONSTRAINT invoice_write_offs_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.invoice_write_offs TO anon;

GRANT ALL ON public.invoice_write_offs TO authenticated;

GRANT ALL ON public.invoice_write_offs TO service_role;