CREATE TABLE public.thrift_invoices (
  id                       bigint                           DEFAULT nextval('public.thrift_invoices_id_seq'::regclass) NOT NULL,
  tenant_id                bigint                           NOT NULL,
  invoice_number           text                             NOT NULL,
  recipient_name           text                             NOT NULL,
  address                  text                             NOT NULL,
  phone                    text                             NOT NULL,
  transaction_method       public.thrift_transaction_method NOT NULL,
  delivery_status          public.thrift_delivery_status    DEFAULT 'PENDING'::public.thrift_delivery_status NOT NULL,
  payment_status           public.thrift_payment_status     DEFAULT 'UNPAID'::public.thrift_payment_status NOT NULL,
  cod_charge               numeric(12,2)                    DEFAULT 0.00 NOT NULL,
  packing_charge           numeric(12,2)                    DEFAULT 0.00 NOT NULL,
  invoice_print_charge     numeric(12,2)                    DEFAULT 0.00 NOT NULL,
  shipping_charge_customer numeric(12,2)                    DEFAULT 0.00 NOT NULL,
  total_invoice_amount     numeric(12,2)                    DEFAULT 0.00 NOT NULL,
  inserted_by              text                             NOT NULL,
  created_at               timestamp with time zone         DEFAULT now() NOT NULL,
  updated_at               timestamp with time zone         DEFAULT now() NOT NULL
);

CREATE TRIGGER trg_thrift_invoices_updated_at
  BEFORE UPDATE ON public.thrift_invoices
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY select_thrift_invoices ON public.thrift_invoices
  FOR SELECT
  TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE ((m.tenant_id = thrift_invoices.tenant_id) AND (lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.is_active = true)))));

COMMENT ON TABLE public.thrift_invoices IS 'LEGACY ARCHIVE — read-only (P21). Active sales use thrift_sales_invoices.';

ALTER SEQUENCE public.thrift_invoices_id_seq OWNED BY public.thrift_invoices.id;

ALTER TABLE public.thrift_invoices
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.thrift_invoices
  ADD CONSTRAINT thrift_invoices_cod_charge_check CHECK (cod_charge >= 0::numeric);

ALTER TABLE public.thrift_invoices
  ADD CONSTRAINT thrift_invoices_invoice_print_charge_check CHECK (invoice_print_charge >= 0::numeric);

ALTER TABLE public.thrift_invoices
  ADD CONSTRAINT thrift_invoices_number_tenant_unique UNIQUE (tenant_id, invoice_number);

ALTER TABLE public.thrift_invoices
  ADD CONSTRAINT thrift_invoices_packing_charge_check CHECK (packing_charge >= 0::numeric);

ALTER TABLE public.thrift_invoices
  ADD CONSTRAINT thrift_invoices_pkey PRIMARY KEY (id);

ALTER TABLE public.thrift_invoices
  ADD CONSTRAINT thrift_invoices_shipping_charge_customer_check CHECK (shipping_charge_customer >= 0::numeric);

ALTER TABLE public.thrift_invoices
  ADD CONSTRAINT thrift_invoices_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

ALTER TABLE public.thrift_invoices
  ADD CONSTRAINT thrift_invoices_total_invoice_amount_check CHECK (total_invoice_amount >= 0::numeric);

GRANT ALL ON public.thrift_invoices TO anon;

GRANT ALL ON public.thrift_invoices TO authenticated;

GRANT ALL ON public.thrift_invoices TO service_role;