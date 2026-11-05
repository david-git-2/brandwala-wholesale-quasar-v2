CREATE TABLE public.global_stocks (
  id               bigint                    DEFAULT nextval('public.global_stocks_id_seq'::regclass) NOT NULL,
  parent_tenant_id bigint                    NOT NULL,
  shipment_item_id bigint                    NOT NULL,
  stock_type_id    bigint,
  quantity         integer                   DEFAULT 0 NOT NULL,
  is_usable        boolean                   DEFAULT true NOT NULL,
  created_at       timestamp with time zone  DEFAULT now() NOT NULL,
  updated_at       timestamp with time zone  DEFAULT now() NOT NULL,
  availability     public.stock_availability DEFAULT 'sellable'::public.stock_availability NOT NULL,
  location_id      bigint,
  grade_tag_id     bigint,
  outcome_id       bigint,
  is_archived      boolean                   DEFAULT false NOT NULL,
  archived_at      timestamp with time zone
);

CREATE INDEX global_stocks_parent_tenant_is_archived_idx ON public.global_stocks (parent_tenant_id, is_archived);

CREATE INDEX global_stocks_shipment_item_idx ON public.global_stocks (shipment_item_id);

CREATE INDEX global_stocks_stock_type_idx ON public.global_stocks (stock_type_id);

CREATE INDEX global_stocks_parent_tenant_idx ON public.global_stocks (parent_tenant_id);

CREATE INDEX global_stocks_outcome_id_idx ON public.global_stocks (outcome_id)
  WHERE outcome_id IS NOT NULL;

CREATE INDEX global_stocks_location_id_idx ON public.global_stocks (location_id);

CREATE INDEX global_stocks_availability_idx ON public.global_stocks (availability);

CREATE TRIGGER trg_global_stocks_updated_at
  BEFORE UPDATE ON public.global_stocks
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY global_stocks_all ON public.global_stocks
  TO authenticated
  USING (public.user_can_manage_parent_tenant(parent_tenant_id))
  WITH CHECK (public.user_can_manage_parent_tenant(parent_tenant_id));

COMMENT ON COLUMN public.global_stocks.availability IS 'Stock pool availability state for warehouse & ATP calculation.';

COMMENT ON COLUMN public.global_stocks.location_id IS 'Warehouse bin / location where stock is located.';

COMMENT ON COLUMN public.global_stocks.is_archived IS 'When true, stock is hidden from operational warehouse views (e.g. archived shipment).';

COMMENT ON CONSTRAINT global_stocks_outcome_grain_unique ON public.global_stocks IS 'One lot row per outcome × availability × bin × grade (US-7).';

ALTER SEQUENCE public.global_stocks_id_seq OWNED BY public.global_stocks.id;

ALTER TABLE public.global_stocks
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.global_stocks
  ADD CONSTRAINT global_stocks_outcome_grain_unique UNIQUE (outcome_id, availability, location_id, grade_tag_id);

ALTER TABLE public.global_stocks
  ADD CONSTRAINT global_stocks_outcome_id_fkey FOREIGN KEY (outcome_id) REFERENCES public.global_shipment_item_outcomes(id) ON DELETE SET NULL;

ALTER TABLE public.global_stocks
  ADD CONSTRAINT global_stocks_pkey PRIMARY KEY (id);

ALTER TABLE public.global_stocks
  ADD CONSTRAINT global_stocks_quantity_check CHECK (quantity >= 0);

ALTER TABLE public.global_stocks
  ADD CONSTRAINT global_stocks_shipment_item_id_fkey FOREIGN KEY (shipment_item_id) REFERENCES public.global_shipment_items(id) ON DELETE CASCADE;

ALTER TABLE public.global_stocks
  ADD CONSTRAINT global_stocks_stock_type_id_fkey FOREIGN KEY (stock_type_id) REFERENCES public.global_stock_types(id) ON DELETE CASCADE;

ALTER TABLE public.global_stocks
  ADD CONSTRAINT global_stocks_location_id_fkey FOREIGN KEY (location_id) REFERENCES public.stock_locations(id) ON DELETE SET NULL;

ALTER TABLE public.global_stocks
  ADD CONSTRAINT global_stocks_grade_tag_id_fkey FOREIGN KEY (grade_tag_id) REFERENCES public.tags(id);

ALTER TABLE public.global_stocks
  ADD CONSTRAINT global_stocks_parent_tenant_id_fkey FOREIGN KEY (parent_tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.global_stocks TO anon;

GRANT ALL ON public.global_stocks TO authenticated;

GRANT ALL ON public.global_stocks TO service_role;