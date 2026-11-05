CREATE TABLE public.sales_return_items (
  id                   bigint                   DEFAULT nextval('public.global_return_items_id_seq'::regclass) NOT NULL,
  parent_tenant_id     bigint                   NOT NULL,
  invoice_id           bigint                   NOT NULL,
  invoice_item_id      bigint                   NOT NULL,
  global_stock_id      bigint,
  quantity             numeric(12,3)            NOT NULL,
  return_charge_amount numeric(12,2)            DEFAULT 0 NOT NULL,
  note                 text,
  created_at           timestamp with time zone DEFAULT now() NOT NULL,
  updated_at           timestamp with time zone DEFAULT now() NOT NULL
);

CREATE INDEX global_return_items_invoice_id_idx ON public.sales_return_items (invoice_id);

CREATE INDEX global_return_items_invoice_item_id_idx ON public.sales_return_items (invoice_item_id);

CREATE TRIGGER trg_global_return_items_set_updated_at
  BEFORE UPDATE ON public.sales_return_items
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY global_return_items_all ON public.sales_return_items
  TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM public.bills gi
  WHERE (gi.id = sales_return_items.invoice_id))))
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.bills gi
  WHERE (gi.id = sales_return_items.invoice_id))));

ALTER SEQUENCE public.global_return_items_id_seq OWNED BY public.sales_return_items.id;

ALTER TABLE public.sales_return_items
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.sales_return_items
  ADD CONSTRAINT global_return_items_global_stock_id_fkey FOREIGN KEY (global_stock_id) REFERENCES public.global_stocks(id) ON DELETE SET NULL;

ALTER TABLE public.sales_return_items
  ADD CONSTRAINT global_return_items_invoice_id_fkey FOREIGN KEY (invoice_id) REFERENCES public.bills(id) ON DELETE CASCADE;

ALTER TABLE public.sales_return_items
  ADD CONSTRAINT global_return_items_invoice_item_id_fkey FOREIGN KEY (invoice_item_id) REFERENCES public.bill_lines(id) ON DELETE CASCADE;

ALTER TABLE public.sales_return_items
  ADD CONSTRAINT global_return_items_pkey PRIMARY KEY (id);

ALTER TABLE public.sales_return_items
  ADD CONSTRAINT global_return_items_quantity_check CHECK (quantity > 0::numeric);

ALTER TABLE public.sales_return_items
  ADD CONSTRAINT global_return_items_return_charge_amount_check CHECK (return_charge_amount >= 0::numeric);

ALTER TABLE public.sales_return_items
  ADD CONSTRAINT global_return_items_parent_tenant_id_fkey FOREIGN KEY (parent_tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.sales_return_items TO anon;

GRANT ALL ON public.sales_return_items TO authenticated;

GRANT ALL ON public.sales_return_items TO service_role;