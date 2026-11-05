CREATE TABLE public.bill_lines (
  id                       bigint                   DEFAULT nextval('public.global_invoice_items_id_seq'::regclass) NOT NULL,
  parent_tenant_id         bigint                   NOT NULL,
  invoice_id               bigint                   NOT NULL,
  shipment_item_id         bigint,
  product_id               bigint,
  name_snapshot            text                     NOT NULL,
  barcode_snapshot         text,
  product_code_snapshot    text,
  quantity                 numeric(12,3)            NOT NULL,
  sell_price_amount        numeric(12,2)            DEFAULT 0 NOT NULL,
  line_discount_amount     numeric(12,2)            DEFAULT 0 NOT NULL,
  line_total_amount        numeric(12,2)            DEFAULT 0 NOT NULL,
  return_quantity          numeric(12,3)            DEFAULT 0 NOT NULL,
  created_at               timestamp with time zone DEFAULT now() NOT NULL,
  updated_at               timestamp with time zone DEFAULT now() NOT NULL,
  assigned_child_tenant_id bigint,
  line_meta                jsonb                    DEFAULT '{}'::jsonb NOT NULL,
  line_kind                text                     DEFAULT 'stock'::text NOT NULL,
  currency_code            text                     DEFAULT 'BDT'::text NOT NULL,
  books_amount             numeric(12,2)
);

CREATE INDEX idx_global_invoice_items_shipment ON public.bill_lines (shipment_item_id);

CREATE INDEX global_invoice_items_invoice_id_idx ON public.bill_lines (invoice_id);

CREATE INDEX global_invoice_items_global_stock_id_idx ON public.bill_lines ((((line_meta -> 'stock_ref'::text) ->> 'global_stock_id'::text)::bigint))
  WHERE ((line_meta -> 'stock_ref'::text) ->> 'global_stock_id'::text) IS NOT NULL;

CREATE TRIGGER trg_global_invoice_items_set_updated_at
  BEFORE UPDATE ON public.bill_lines
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY global_invoice_items_all ON public.bill_lines
  TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM public.bills gi
  WHERE (gi.id = bill_lines.invoice_id))))
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.bills gi
  WHERE (gi.id = bill_lines.invoice_id))));

ALTER SEQUENCE public.global_invoice_items_id_seq OWNED BY public.bill_lines.id;

ALTER TABLE public.bill_lines
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.bill_lines
  ADD CONSTRAINT bill_lines_line_kind_check CHECK (line_kind = ANY (ARRAY['stock'::text, 'description'::text, 'charge'::text]));

ALTER TABLE public.bill_lines
  ADD CONSTRAINT global_invoice_items_line_discount_amount_check CHECK (line_discount_amount >= 0::numeric);

ALTER TABLE public.bill_lines
  ADD CONSTRAINT global_invoice_items_line_total_amount_check CHECK (line_total_amount >= 0::numeric);

ALTER TABLE public.bill_lines
  ADD CONSTRAINT global_invoice_items_pkey PRIMARY KEY (id);

ALTER TABLE public.bill_lines
  ADD CONSTRAINT global_invoice_items_quantity_check CHECK (quantity > 0::numeric);

ALTER TABLE public.bill_lines
  ADD CONSTRAINT global_invoice_items_return_qty_check CHECK (return_quantity <= quantity);

ALTER TABLE public.bill_lines
  ADD CONSTRAINT global_invoice_items_return_quantity_check CHECK (return_quantity >= 0::numeric);

ALTER TABLE public.bill_lines
  ADD CONSTRAINT global_invoice_items_sell_price_amount_check CHECK (sell_price_amount >= 0::numeric);

ALTER TABLE public.bill_lines
  ADD CONSTRAINT global_invoice_items_invoice_id_fkey FOREIGN KEY (invoice_id) REFERENCES public.bills(id) ON DELETE CASCADE;

ALTER TABLE public.bill_lines
  ADD CONSTRAINT global_invoice_items_shipment_item_id_fkey FOREIGN KEY (shipment_item_id) REFERENCES public.global_shipment_items(id) ON DELETE SET NULL;

ALTER TABLE public.bill_lines
  ADD CONSTRAINT global_invoice_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE SET NULL;

ALTER TABLE public.bill_lines
  ADD CONSTRAINT global_invoice_items_assigned_child_tenant_id_fkey FOREIGN KEY (assigned_child_tenant_id) REFERENCES public.tenants(id);

ALTER TABLE public.bill_lines
  ADD CONSTRAINT global_invoice_items_parent_tenant_id_fkey FOREIGN KEY (parent_tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.bill_lines TO anon;

GRANT ALL ON public.bill_lines TO authenticated;

GRANT ALL ON public.bill_lines TO service_role;