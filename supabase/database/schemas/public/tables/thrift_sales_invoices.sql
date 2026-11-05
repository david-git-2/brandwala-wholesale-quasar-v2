CREATE TABLE public.thrift_sales_invoices (
  id                       bigint                   DEFAULT nextval('public.thrift_sales_invoices_id_seq'::regclass) NOT NULL,
  tenant_id                bigint                   NOT NULL,
  invoice_number           text                     NOT NULL,
  date                     timestamp with time zone DEFAULT now() NOT NULL,
  payment_method           text                     DEFAULT 'CASH'::text NOT NULL,
  payment_status           text                     DEFAULT 'PAID'::text NOT NULL,
  total_invoice_amount     numeric(12,2)            DEFAULT 0.00 NOT NULL,
  created_by               text                     DEFAULT ''::text NOT NULL,
  notes                    text,
  created_at               timestamp with time zone DEFAULT now() NOT NULL,
  updated_at               timestamp with time zone DEFAULT now() NOT NULL,
  customer_name            text,
  customer_phone           text,
  status                   text                     DEFAULT 'ACTIVE'::text NOT NULL,
  reverted_at              timestamp with time zone,
  reverted_by              text,
  revert_reason            text,
  revert_notes             text,
  sale_channel             text                     DEFAULT 'IN_STORE'::text NOT NULL,
  customer_id              bigint,
  customer_address         text,
  courier_cod_amount       numeric(12,2)            DEFAULT 0.00 NOT NULL,
  other_expense_amount     numeric(12,2)            DEFAULT 0.00 NOT NULL,
  courier_amount           numeric(12,2)            DEFAULT 0.00 NOT NULL,
  courier_paid_by          text,
  cod_expected             numeric(12,2),
  cod_remitted_amount      numeric(12,2),
  cod_remitted_at          timestamp with time zone,
  cod_remittance_ref       text,
  delivery_status          text,
  courier_provider         text,
  cod_fee_amount           numeric(12,2)            DEFAULT 0.00 NOT NULL,
  cod_fee_paid_by          text,
  packing_amount           numeric(12,2)            DEFAULT 0.00 NOT NULL,
  packing_paid_by          text,
  return_courier_amount    numeric(12,2)            DEFAULT 0.00 NOT NULL,
  close_reason             text,
  economics_closed_at      timestamp with time zone,
  courier_provider_id      bigint,
  meta                     jsonb                    DEFAULT '{}'::jsonb NOT NULL,
  customer_secondary_phone text,
  customer_address_parts   jsonb                    DEFAULT '{}'::jsonb NOT NULL,
  advance_amount           numeric(12,2)            DEFAULT 0.00 NOT NULL,
  advance_note             text
);

CREATE INDEX idx_thrift_sales_invoices_tenant_customer ON public.thrift_sales_invoices (tenant_id, customer_id)
  WHERE customer_id IS NOT NULL;

CREATE INDEX idx_thrift_sales_invoices_tenant_date ON public.thrift_sales_invoices (tenant_id, date DESC);

CREATE INDEX idx_thrift_sales_invoices_tenant_status ON public.thrift_sales_invoices (tenant_id, status);

CREATE INDEX idx_thrift_sales_invoices_tenant_delivery_status ON public.thrift_sales_invoices (tenant_id, delivery_status)
  WHERE delivery_status IS NOT NULL;

CREATE INDEX idx_thrift_sales_invoices_courier_provider ON public.thrift_sales_invoices (courier_provider_id)
  WHERE courier_provider_id IS NOT NULL;

CREATE INDEX idx_thrift_sales_invoices_tenant_close_reason ON public.thrift_sales_invoices (tenant_id, close_reason)
  WHERE close_reason IS NOT NULL;

CREATE POLICY "Members can view thrift sales invoices for their tenant" ON public.thrift_sales_invoices
  FOR SELECT
  TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE ((m.tenant_id = thrift_sales_invoices.tenant_id) AND (lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.is_active = true)))));

CREATE POLICY "Staff and Admins can insert thrift sales invoices" ON public.thrift_sales_invoices
  FOR INSERT
  TO authenticated
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE
    ((m.tenant_id = thrift_sales_invoices.tenant_id) AND (lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.is_active = true) AND (m.role = ANY
    (ARRAY['superadmin'::public.app_role, 'admin'::public.app_role, 'manager'::public.app_role, 'staff'::public.app_role, 'cashier'::public.app_role]))))));

CREATE POLICY "Staff and Admins can update thrift sales invoices" ON public.thrift_sales_invoices
  FOR UPDATE
  TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE
    ((m.tenant_id = thrift_sales_invoices.tenant_id) AND (lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.is_active = true) AND (m.role = ANY
    (ARRAY['superadmin'::public.app_role, 'admin'::public.app_role, 'manager'::public.app_role, 'staff'::public.app_role, 'cashier'::public.app_role]))))));

COMMENT ON COLUMN public.thrift_sales_invoices.customer_name IS 'Customer full name for thrift invoice';

COMMENT ON COLUMN public.thrift_sales_invoices.customer_phone IS 'Customer phone number for thrift invoice';

COMMENT ON COLUMN public.thrift_sales_invoices.sale_channel IS 'Hybrid desk channel: IN_STORE | ONLINE';

COMMENT ON COLUMN public.thrift_sales_invoices.customer_id IS 'Linked thrift_customers row when phone was present at sale';

COMMENT ON COLUMN public.thrift_sales_invoices.customer_address IS 'Sale-day address snapshot';

COMMENT ON COLUMN public.thrift_sales_invoices.courier_cod_amount IS 'DEPRECATED — use courier_amount. Retained for historical rows / reports.';

COMMENT ON COLUMN public.thrift_sales_invoices.other_expense_amount IS 'DEPRECATED — no longer written by create_thrift_sales_invoice.';

COMMENT ON COLUMN public.thrift_sales_invoices.courier_amount IS 'Courier fee amount (>= 0). Offline always 0.';

COMMENT ON COLUMN public.thrift_sales_invoices.courier_paid_by IS 'CUSTOMER | SHOP when courier_amount > 0; null when amount is 0.';

COMMENT ON COLUMN public.thrift_sales_invoices.cod_expected IS 'COD cash expected from courier (Online COD_PENDING). Null offline / paid-at-create.';

COMMENT ON COLUMN public.thrift_sales_invoices.delivery_status IS 'Parcel track for Online invoices. Null for Offline. Independent of payment_status.';

COMMENT ON COLUMN public.thrift_sales_invoices.courier_provider IS 'Online optional courier company name; Offline null.';

COMMENT ON COLUMN public.thrift_sales_invoices.cod_fee_amount IS 'Courier COD service fee (staff-entered ৳), not a stored %.';

COMMENT ON COLUMN public.thrift_sales_invoices.packing_amount IS 'Packing / print charge.';

COMMENT ON COLUMN public.thrift_sales_invoices.return_courier_amount IS 'RTO / no-pickup return courier billed to shop (post-pay returns use thrift_sales_returns).';

COMMENT ON COLUMN public.thrift_sales_invoices.close_reason IS 'RTO | CUSTOMER_RETURN when fully closed; null while open or partially returned.';

COMMENT ON COLUMN public.thrift_sales_invoices.economics_closed_at IS 'Last time thrift_sales_pnl_lines were written/updated for this invoice.';

COMMENT ON COLUMN public.thrift_sales_invoices.courier_provider_id IS 'Optional FK to thrift_courier_providers; name also snapshotted in courier_provider.';

COMMENT ON COLUMN public.thrift_sales_invoices.meta IS 'Optional Online extras (tracking_id, tracking_url). Not fee amounts.';

COMMENT ON COLUMN public.thrift_sales_invoices.customer_secondary_phone IS 'Snapshot of customer secondary phone at create.';

COMMENT ON COLUMN public.thrift_sales_invoices.customer_address_parts IS 'Snapshot of address_parts at create: { district, thana, post_code }.';

COMMENT ON COLUMN public.thrift_sales_invoices.advance_amount IS 'Customer advance collected at create (online COD only). Deducted from cod_expected; non-refundable. Offline always 0.';

COMMENT ON COLUMN public.thrift_sales_invoices.advance_note IS 'Optional note for advance (e.g. payment ref). Null when unused.';

ALTER SEQUENCE public.thrift_sales_invoices_id_seq OWNED BY public.thrift_sales_invoices.id;

ALTER TABLE public.thrift_sales_invoices
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.thrift_sales_invoices
  ADD CONSTRAINT thrift_sales_invoices_advance_amount_check CHECK (advance_amount >= 0::numeric);

ALTER TABLE public.thrift_sales_invoices
  ADD CONSTRAINT thrift_sales_invoices_close_reason_check CHECK (close_reason IS NULL OR (close_reason = ANY (ARRAY['RTO'::text, 'CUSTOMER_RETURN'::text])));

ALTER TABLE public.thrift_sales_invoices
  ADD CONSTRAINT thrift_sales_invoices_cod_expected_check CHECK (cod_expected IS NULL OR cod_expected >= 0::numeric);

ALTER TABLE public.thrift_sales_invoices
  ADD CONSTRAINT thrift_sales_invoices_cod_fee_amount_check CHECK (cod_fee_amount >= 0::numeric);

ALTER TABLE public.thrift_sales_invoices
  ADD CONSTRAINT thrift_sales_invoices_cod_fee_paid_by_check CHECK (cod_fee_paid_by IS NULL OR (cod_fee_paid_by = ANY (ARRAY['CUSTOMER'::text, 'SHOP'::text])));

ALTER TABLE public.thrift_sales_invoices
  ADD CONSTRAINT thrift_sales_invoices_cod_fee_payer_consistency_check CHECK (cod_fee_amount > 0::numeric AND cod_fee_paid_by IS
    NOT NULL OR cod_fee_amount = 0::numeric AND cod_fee_paid_by IS NULL);

ALTER TABLE public.thrift_sales_invoices
  ADD CONSTRAINT thrift_sales_invoices_cod_remitted_amount_check CHECK (cod_remitted_amount IS NULL OR cod_remitted_amount >= 0::numeric);

ALTER TABLE public.thrift_sales_invoices
  ADD CONSTRAINT thrift_sales_invoices_courier_amount_check CHECK (courier_amount >= 0::numeric);

ALTER TABLE public.thrift_sales_invoices
  ADD CONSTRAINT thrift_sales_invoices_courier_cod_amount_check CHECK (courier_cod_amount >= 0::numeric);

ALTER TABLE public.thrift_sales_invoices
  ADD CONSTRAINT thrift_sales_invoices_courier_paid_by_check CHECK (courier_paid_by IS NULL OR (courier_paid_by = ANY (ARRAY['CUSTOMER'::text, 'SHOP'::text])));

ALTER TABLE public.thrift_sales_invoices
  ADD CONSTRAINT thrift_sales_invoices_courier_payer_amount_check CHECK (courier_amount > 0::numeric AND courier_paid_by IS
    NOT NULL OR courier_amount = 0::numeric AND courier_paid_by IS NULL);

ALTER TABLE public.thrift_sales_invoices
  ADD CONSTRAINT thrift_sales_invoices_courier_provider_id_fkey FOREIGN KEY (courier_provider_id) REFERENCES public.thrift_courier_providers(id) ON DELETE SET NULL;

ALTER TABLE public.thrift_sales_invoices
  ADD CONSTRAINT thrift_sales_invoices_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.thrift_customers(id) ON DELETE SET NULL;

ALTER TABLE public.thrift_sales_invoices
  ADD CONSTRAINT thrift_sales_invoices_delivery_status_check
    CHECK (delivery_status IS NULL OR (delivery_status = ANY (ARRAY['PENDING'::text, 'READY'::text, 'IN_TRANSIT'::text, 'DELIVERED'::text, 'RETURNED'::text])));

ALTER TABLE public.thrift_sales_invoices
  ADD CONSTRAINT thrift_sales_invoices_other_expense_amount_check CHECK (other_expense_amount >= 0::numeric);

ALTER TABLE public.thrift_sales_invoices
  ADD CONSTRAINT thrift_sales_invoices_packing_amount_check CHECK (packing_amount >= 0::numeric);

ALTER TABLE public.thrift_sales_invoices
  ADD CONSTRAINT thrift_sales_invoices_packing_paid_by_check CHECK (packing_paid_by IS NULL OR (packing_paid_by = ANY (ARRAY['CUSTOMER'::text, 'SHOP'::text])));

ALTER TABLE public.thrift_sales_invoices
  ADD CONSTRAINT thrift_sales_invoices_packing_payer_consistency_check CHECK (packing_amount > 0::numeric AND packing_paid_by IS
    NOT NULL OR packing_amount = 0::numeric AND packing_paid_by IS NULL);

ALTER TABLE public.thrift_sales_invoices
  ADD CONSTRAINT thrift_sales_invoices_payment_status_check
    CHECK (payment_status = ANY (ARRAY['PAID'::text, 'COD_PENDING'::text, 'PARTIALLY_REFUNDED'::text, 'REFUNDED'::text, 'WRITTEN_OFF'::text, 'UNPAID'::text]));

ALTER TABLE public.thrift_sales_invoices
  ADD CONSTRAINT thrift_sales_invoices_pkey PRIMARY KEY (id);

ALTER TABLE public.thrift_sales_invoices
  ADD CONSTRAINT thrift_sales_invoices_return_courier_amount_check CHECK (return_courier_amount >= 0::numeric);

ALTER TABLE public.thrift_sales_invoices
  ADD CONSTRAINT thrift_sales_invoices_sale_channel_check CHECK (sale_channel = ANY (ARRAY['IN_STORE'::text, 'ONLINE'::text]));

ALTER TABLE public.thrift_sales_invoices
  ADD CONSTRAINT thrift_sales_invoices_status_check CHECK (status = ANY (ARRAY['ACTIVE'::text, 'PARTIALLY_RETURNED'::text, 'RETURNED'::text, 'STAFF_MISTAKE'::text]));

ALTER TABLE public.thrift_sales_invoices
  ADD CONSTRAINT thrift_sales_invoices_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

ALTER TABLE public.thrift_sales_invoices
  ADD CONSTRAINT thrift_sales_invoices_tenant_num_key UNIQUE (tenant_id, invoice_number);

GRANT ALL ON public.thrift_sales_invoices TO anon;

GRANT ALL ON public.thrift_sales_invoices TO authenticated;

GRANT ALL ON public.thrift_sales_invoices TO service_role;