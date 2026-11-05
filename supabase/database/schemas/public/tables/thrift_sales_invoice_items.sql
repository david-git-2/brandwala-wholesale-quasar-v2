CREATE TABLE public.thrift_sales_invoice_items (
  id                       bigint                   DEFAULT nextval('public.thrift_sales_invoice_items_id_seq'::regclass) NOT NULL,
  invoice_id               bigint                   NOT NULL,
  tenant_id                bigint                   NOT NULL,
  stock_id                 bigint,
  sell_price               numeric(12,2)            DEFAULT 0.00 NOT NULL,
  discount_amount          numeric(12,2)            DEFAULT 0.00 NOT NULL,
  final_price              numeric(12,2)            DEFAULT 0.00 NOT NULL,
  quantity                 integer                  DEFAULT 1 NOT NULL,
  landed_unit_cost_at_sale numeric(12,2)            DEFAULT 0.00 NOT NULL,
  net_profit               numeric(12,2)            DEFAULT 0.00 NOT NULL,
  created_at               timestamp with time zone DEFAULT now() NOT NULL,
  updated_at               timestamp with time zone DEFAULT now() NOT NULL
);

CREATE INDEX idx_thrift_sales_invoice_items_invoice ON public.thrift_sales_invoice_items (invoice_id);

CREATE INDEX idx_thrift_sales_invoice_items_stock ON public.thrift_sales_invoice_items (stock_id);

CREATE POLICY "Members can view thrift sales invoice items" ON public.thrift_sales_invoice_items
  FOR SELECT
  TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE ((m.tenant_id = thrift_sales_invoice_items.tenant_id) AND (lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.is_active = true)))));

CREATE POLICY "Staff and Admins can insert thrift sales invoice items" ON public.thrift_sales_invoice_items
  FOR INSERT
  TO authenticated
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE
    ((m.tenant_id = thrift_sales_invoice_items.tenant_id) AND (lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.is_active = true) AND (m.role = ANY
    (ARRAY['superadmin'::public.app_role, 'admin'::public.app_role, 'manager'::public.app_role, 'staff'::public.app_role, 'cashier'::public.app_role]))))));

ALTER SEQUENCE public.thrift_sales_invoice_items_id_seq OWNED BY public.thrift_sales_invoice_items.id;

ALTER TABLE public.thrift_sales_invoice_items
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.thrift_sales_invoice_items
  ADD CONSTRAINT thrift_sales_invoice_items_pkey PRIMARY KEY (id);

ALTER TABLE public.thrift_sales_invoice_items
  ADD CONSTRAINT thrift_sales_invoice_items_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

ALTER TABLE public.thrift_sales_invoice_items
  ADD CONSTRAINT thrift_sales_invoice_items_invoice_id_fkey FOREIGN KEY (invoice_id) REFERENCES public.thrift_sales_invoices(id) ON DELETE CASCADE;

ALTER TABLE public.thrift_sales_invoice_items
  ADD CONSTRAINT thrift_sales_invoice_items_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES public.thrift_stocks(id) ON DELETE SET NULL;

GRANT ALL ON public.thrift_sales_invoice_items TO anon;

GRANT ALL ON public.thrift_sales_invoice_items TO authenticated;

GRANT ALL ON public.thrift_sales_invoice_items TO service_role;