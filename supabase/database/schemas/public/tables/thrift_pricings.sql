CREATE TABLE public.thrift_pricings (
  id                     bigint                   DEFAULT nextval('public.thrift_pricings_id_seq'::regclass) NOT NULL,
  stock_id               bigint                   NOT NULL,
  cost_of_goods_sold     numeric(12,2)            DEFAULT 0.00 NOT NULL,
  target_price           numeric(12,2)            DEFAULT 0.00 NOT NULL,
  listed_unit_price      numeric(12,2)            DEFAULT 0.00 NOT NULL,
  inserted_by            text                     NOT NULL,
  created_at             timestamp with time zone DEFAULT now() NOT NULL,
  updated_at             timestamp with time zone DEFAULT now() NOT NULL,
  extra_expense_cost     numeric(12,2)            DEFAULT 0.00 NOT NULL,
  is_listed_price_manual boolean                  DEFAULT false,
  markup_rate_override   numeric
);

CREATE TRIGGER trg_thrift_pricings_updated_at
  BEFORE UPDATE ON public.thrift_pricings
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY select_thrift_pricings ON public.thrift_pricings
  FOR SELECT
  TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM (public.thrift_stocks s
     JOIN public.memberships m ON ((m.tenant_id = s.tenant_id)))
  WHERE ((s.id = thrift_pricings.stock_id) AND (lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.is_active = true)))));

CREATE POLICY write_thrift_pricings ON public.thrift_pricings
  TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM public.thrift_stocks s
  WHERE ((s.id = thrift_pricings.stock_id) AND public.membership_has_module_action(s.tenant_id, 'thrift_stock'::text, 'edit'::text)))));

COMMENT ON COLUMN public.thrift_pricings.cost_of_goods_sold IS 'DEPRECATED (P22) — do not use as sale/report COGS. Source of truth: compute_thrift_landed_unit_cost + thrift_sales_invoice_items.landed_unit_cost_at_sale. Column retained until Wave 2+ drop.';

COMMENT ON COLUMN public.thrift_pricings.target_price IS 'DEPRECATED (P22) — prefer listed_unit_price + engine suggested sell. Column retained until Wave 2+ drop.';

COMMENT ON COLUMN public.thrift_pricings.extra_expense_cost IS 'DEPRECATED (P22) — not used by costing engine. Column retained until Wave 2+ drop.';

ALTER SEQUENCE public.thrift_pricings_id_seq OWNED BY public.thrift_pricings.id;

ALTER TABLE public.thrift_pricings
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.thrift_pricings
  ADD CONSTRAINT thrift_pricings_cost_of_goods_sold_check CHECK (cost_of_goods_sold >= 0::numeric);

ALTER TABLE public.thrift_pricings
  ADD CONSTRAINT thrift_pricings_extra_expense_cost_check CHECK (extra_expense_cost >= 0::numeric);

ALTER TABLE public.thrift_pricings
  ADD CONSTRAINT thrift_pricings_listed_price_check CHECK (listed_unit_price >= 0::numeric);

ALTER TABLE public.thrift_pricings
  ADD CONSTRAINT thrift_pricings_pkey PRIMARY KEY (id);

ALTER TABLE public.thrift_pricings
  ADD CONSTRAINT thrift_pricings_stock_id_key UNIQUE (stock_id);

ALTER TABLE public.thrift_pricings
  ADD CONSTRAINT thrift_pricings_target_price_check CHECK (target_price >= 0::numeric);

ALTER TABLE public.thrift_pricings
  ADD CONSTRAINT thrift_pricings_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES public.thrift_stocks(id) ON DELETE CASCADE;

GRANT ALL ON public.thrift_pricings TO anon;

GRANT ALL ON public.thrift_pricings TO authenticated;

GRANT ALL ON public.thrift_pricings TO service_role;