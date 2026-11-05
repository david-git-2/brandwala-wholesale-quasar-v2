CREATE TABLE public.courier_remittance_items (
  id                    bigint                   GENERATED ALWAYS AS IDENTITY NOT NULL,
  tenant_id             bigint                   NOT NULL,
  batch_id              bigint                   NOT NULL,
  shop_order_id         bigint,
  global_invoice_id     bigint,
  tracking_number       text,
  awb_number            text,
  cod_collected_amount  numeric(12,2)            DEFAULT 0.00 NOT NULL,
  courier_charge_amount numeric(12,2)            DEFAULT 0.00 NOT NULL,
  net_remitted_amount   numeric(12,2)            DEFAULT 0.00 NOT NULL,
  status                text                     DEFAULT 'matched'::text NOT NULL,
  error_message         text,
  created_at            timestamp with time zone DEFAULT now() NOT NULL
);

CREATE INDEX idx_courier_remittance_items_tenant ON public.courier_remittance_items (tenant_id);

CREATE INDEX idx_courier_remittance_items_tracking ON public.courier_remittance_items (tracking_number);

CREATE INDEX idx_courier_remittance_items_order ON public.courier_remittance_items (shop_order_id);

CREATE INDEX idx_courier_remittance_items_invoice ON public.courier_remittance_items (global_invoice_id);

CREATE INDEX idx_courier_remittance_items_batch ON public.courier_remittance_items (batch_id);

CREATE POLICY courier_remittance_items_tenant_isolation ON public.courier_remittance_items
  TO authenticated
  USING ((public.is_superadmin() OR (EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE ((m.tenant_id = courier_remittance_items.tenant_id) AND (lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.is_active = true))))))
  WITH CHECK ((public.is_superadmin() OR (EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE ((m.tenant_id = courier_remittance_items.tenant_id) AND (lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.is_active = true))))));

ALTER TABLE public.courier_remittance_items
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.courier_remittance_items
  ADD CONSTRAINT courier_remittance_items_batch_id_fkey FOREIGN KEY (batch_id) REFERENCES public.courier_remittance_batches(id) ON DELETE CASCADE;

ALTER TABLE public.courier_remittance_items
  ADD CONSTRAINT courier_remittance_items_cod_collected_amount_check CHECK (cod_collected_amount >= 0::numeric);

ALTER TABLE public.courier_remittance_items
  ADD CONSTRAINT courier_remittance_items_courier_charge_amount_check CHECK (courier_charge_amount >= 0::numeric);

ALTER TABLE public.courier_remittance_items
  ADD CONSTRAINT courier_remittance_items_global_invoice_id_fkey FOREIGN KEY (global_invoice_id) REFERENCES public.bills(id) ON DELETE SET NULL;

ALTER TABLE public.courier_remittance_items
  ADD CONSTRAINT courier_remittance_items_net_remitted_amount_check CHECK (net_remitted_amount >= 0::numeric);

ALTER TABLE public.courier_remittance_items
  ADD CONSTRAINT courier_remittance_items_pkey PRIMARY KEY (id);

ALTER TABLE public.courier_remittance_items
  ADD CONSTRAINT courier_remittance_items_status_check CHECK (status = ANY (ARRAY['matched'::text, 'unmatched'::text, 'processed'::text, 'error'::text]));

ALTER TABLE public.courier_remittance_items
  ADD CONSTRAINT courier_remittance_items_shop_order_id_fkey FOREIGN KEY (shop_order_id) REFERENCES public.shop_orders(id) ON DELETE SET NULL;

ALTER TABLE public.courier_remittance_items
  ADD CONSTRAINT courier_remittance_items_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.courier_remittance_items TO anon;

GRANT ALL ON public.courier_remittance_items TO authenticated;

GRANT ALL ON public.courier_remittance_items TO service_role;