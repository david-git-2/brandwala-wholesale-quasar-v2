-- Migration: 20270915000100_payment_allocations_and_write_offs.sql
-- Description: Drop redundant settlement_discount_amount from sales_invoices,
--              add written_off_amount and customer_group_id to payments,
--              and create invoice_write_offs table.

-- 1. Create table invoice_write_offs
CREATE TABLE IF NOT EXISTS public.invoice_write_offs (
    id bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    tenant_id bigint NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    parent_tenant_id bigint NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    invoice_id bigint NOT NULL REFERENCES public.sales_invoices(id) ON DELETE CASCADE,
    payment_id bigint REFERENCES public.global_payments(id) ON DELETE SET NULL,
    amount numeric(12,2) NOT NULL CHECK (amount > 0),
    reason text NOT NULL CHECK (reason IN ('dispute_settlement', 'bad_debt', 'currency_rounding', 'management_concession')),
    note text,
    approved_by uuid REFERENCES auth.users(id),
    created_at timestamptz DEFAULT now() NOT NULL
);

ALTER TABLE public.invoice_write_offs OWNER TO postgres;

-- Indexes on invoice_write_offs
CREATE INDEX IF NOT EXISTS idx_invoice_write_offs_invoice_id ON public.invoice_write_offs(invoice_id);
CREATE INDEX IF NOT EXISTS idx_invoice_write_offs_payment_id ON public.invoice_write_offs(payment_id);
CREATE INDEX IF NOT EXISTS idx_invoice_write_offs_tenant_id ON public.invoice_write_offs(tenant_id);
CREATE INDEX IF NOT EXISTS idx_invoice_write_offs_parent_tenant_id ON public.invoice_write_offs(parent_tenant_id);

-- 2. Add customer_group_id to global_payments (for parent-level payments)
ALTER TABLE public.global_payments
    ADD COLUMN IF NOT EXISTS customer_group_id bigint REFERENCES public.customer_groups(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_global_payments_customer_group_id ON public.global_payments(customer_group_id);

-- 3. Add written_off_amount to sales_invoices
ALTER TABLE public.sales_invoices
    ADD COLUMN IF NOT EXISTS written_off_amount numeric(12,2) DEFAULT 0.00 NOT NULL CHECK (written_off_amount >= 0);

-- 4. Recreate global_invoices compatibility view without settlement_discount_amount
DROP VIEW IF EXISTS public.global_invoices CASCADE;

CREATE VIEW public.global_invoices WITH (security_invoker = false) AS
 SELECT id,
    parent_tenant_id,
    parent_tenant_id AS tenant_id,
    issued_by_tenant_id,
    invoice_no,
    invoice_type,
    invoice_date,
    retail_billing_mode,
    invoice_status,
    fulfillment_status,
    billing_profile_id,
    recipient_profile_id,
    recipient_name,
    recipient_phone,
    recipient_address,
    collection_source,
    due_date,
    payment_status,
    total_amount,
    due_amount,
    paid_amount,
    written_off_amount,
    subtotal_amount,
    discount_amount,
    shipping_charge,
    wrapping_charge,
    print_charge,
    note,
    created_by,
    created_at,
    updated_at,
    cod_charge_amount
   FROM public.sales_invoices;

ALTER VIEW public.global_invoices OWNER TO postgres;

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.global_invoices TO authenticated, service_role;

-- 5. Drop redundant settlement_discount_amount column from sales_invoices
ALTER TABLE public.sales_invoices
    DROP COLUMN IF EXISTS settlement_discount_amount;

-- 6. Enable RLS on invoice_write_offs
ALTER TABLE public.invoice_write_offs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS invoice_write_offs_select ON public.invoice_write_offs;
CREATE POLICY invoice_write_offs_select ON public.invoice_write_offs
    FOR SELECT TO authenticated
    USING (
      EXISTS (
        SELECT 1 FROM public.memberships m
        WHERE m.tenant_id = invoice_write_offs.parent_tenant_id
          AND lower(trim(both from m.email)) = public.current_user_email()
          AND m.is_active = true
      )
      OR
      EXISTS (
        SELECT 1 FROM public.memberships m
        WHERE m.tenant_id = invoice_write_offs.tenant_id
          AND lower(trim(both from m.email)) = public.current_user_email()
          AND m.is_active = true
      )
    );

DROP POLICY IF EXISTS invoice_write_offs_write ON public.invoice_write_offs;
CREATE POLICY invoice_write_offs_write ON public.invoice_write_offs
    FOR ALL TO authenticated
    USING (
      public.membership_has_module_action(parent_tenant_id, 'global_invoice'::text, 'edit'::text)
      OR
      public.membership_has_module_action(tenant_id, 'global_invoice'::text, 'edit'::text)
    )
    WITH CHECK (
      public.membership_has_module_action(parent_tenant_id, 'global_invoice'::text, 'edit'::text)
      OR
      public.membership_has_module_action(tenant_id, 'global_invoice'::text, 'edit'::text)
    );
