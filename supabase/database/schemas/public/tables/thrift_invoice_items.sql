CREATE TABLE public.thrift_invoice_items (
  id                              bigint                      DEFAULT nextval('public.thrift_invoice_items_id_seq'::regclass) NOT NULL,
  invoice_id                      bigint                      NOT NULL,
  stock_id                        bigint                      NOT NULL,
  quantity                        integer                     NOT NULL,
  sold_price                      numeric(12,2)               DEFAULT 0.00 NOT NULL,
  platform_fees                   numeric(12,2)               DEFAULT 0.00 NOT NULL,
  shipping_cost_paid_by_shop      numeric(12,2)               DEFAULT 0.00 NOT NULL,
  item_status                     public.thrift_item_status   DEFAULT 'SOLD'::public.thrift_item_status NOT NULL,
  return_reason                   text,
  return_cost_charged_to_customer numeric(12,2)               DEFAULT 0.00 NOT NULL,
  return_cost_paid_by_shop        numeric(12,2)               DEFAULT 0.00 NOT NULL,
  return_action                   public.thrift_return_action,
  net_profit                      numeric(12,2)               DEFAULT 0.00 NOT NULL,
  created_at                      timestamp with time zone    DEFAULT now() NOT NULL,
  updated_at                      timestamp with time zone    DEFAULT now() NOT NULL,
  landed_unit_cost_at_sale        numeric(12,2)               DEFAULT 0.00 NOT NULL
);

CREATE TRIGGER trg_thrift_invoice_items_profit
  BEFORE INSERT OR UPDATE ON public.thrift_invoice_items
  FOR EACH ROW
  EXECUTE FUNCTION public.calculate_thrift_item_net_profit();

CREATE TRIGGER trg_thrift_invoice_items_total
  AFTER INSERT OR DELETE OR UPDATE ON public.thrift_invoice_items
  FOR EACH ROW
  EXECUTE FUNCTION public.calculate_thrift_invoice_total();

CREATE TRIGGER trg_thrift_invoice_items_updated_at
  BEFORE UPDATE ON public.thrift_invoice_items
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY select_thrift_invoice_items ON public.thrift_invoice_items
  FOR SELECT
  TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM (public.thrift_invoices i
     JOIN public.memberships m ON ((m.tenant_id = i.tenant_id)))
  WHERE ((i.id = thrift_invoice_items.invoice_id) AND (lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.is_active = true)))));

COMMENT ON TABLE public.thrift_invoice_items IS 'LEGACY ARCHIVE — read-only (P21). Active sales use thrift_sales_invoice_items.';

ALTER SEQUENCE public.thrift_invoice_items_id_seq OWNED BY public.thrift_invoice_items.id;

ALTER TABLE public.thrift_invoice_items
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.thrift_invoice_items
  ADD CONSTRAINT thrift_invoice_items_pkey PRIMARY KEY (id);

ALTER TABLE public.thrift_invoice_items
  ADD CONSTRAINT thrift_invoice_items_platform_fees_check CHECK (platform_fees >= 0::numeric);

ALTER TABLE public.thrift_invoice_items
  ADD CONSTRAINT thrift_invoice_items_quantity_check CHECK (quantity > 0);

ALTER TABLE public.thrift_invoice_items
  ADD CONSTRAINT thrift_invoice_items_return_cost_charged_to_customer_check CHECK (return_cost_charged_to_customer >= 0::numeric);

ALTER TABLE public.thrift_invoice_items
  ADD CONSTRAINT thrift_invoice_items_return_cost_paid_by_shop_check CHECK (return_cost_paid_by_shop >= 0::numeric);

ALTER TABLE public.thrift_invoice_items
  ADD CONSTRAINT thrift_invoice_items_shipping_cost_paid_by_shop_check CHECK (shipping_cost_paid_by_shop >= 0::numeric);

ALTER TABLE public.thrift_invoice_items
  ADD CONSTRAINT thrift_invoice_items_sold_price_check CHECK (sold_price >= 0::numeric);

ALTER TABLE public.thrift_invoice_items
  ADD CONSTRAINT thrift_invoice_items_invoice_id_fkey FOREIGN KEY (invoice_id) REFERENCES public.thrift_invoices(id) ON DELETE CASCADE;

ALTER TABLE public.thrift_invoice_items
  ADD CONSTRAINT thrift_invoice_items_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES public.thrift_stocks(id);

GRANT ALL ON public.thrift_invoice_items TO anon;

GRANT ALL ON public.thrift_invoice_items TO authenticated;

GRANT ALL ON public.thrift_invoice_items TO service_role;