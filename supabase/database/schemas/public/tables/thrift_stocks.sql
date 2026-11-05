CREATE TABLE public.thrift_stocks (
  id                        bigint                     DEFAULT nextval('public.thrift_stocks_id_seq'::regclass) NOT NULL,
  tenant_id                 bigint                     NOT NULL,
  shipment_id               bigint                     NOT NULL,
  name                      text,
  brand_name                text,
  category_id               bigint,
  type_id                   bigint,
  section                   public.thrift_section,
  shelf_id                  bigint,
  color                     text,
  size                      text,
  condition                 public.thrift_condition,
  stock_type                public.thrift_stock_type   DEFAULT 'SINGLE'::public.thrift_stock_type NOT NULL,
  quantity                  integer                    DEFAULT 1 NOT NULL,
  status                    public.thrift_stock_status DEFAULT 'AVAILABLE'::public.thrift_stock_status NOT NULL,
  note                      text,
  inserted_by               text                       NOT NULL,
  created_at                timestamp with time zone   DEFAULT now() NOT NULL,
  updated_at                timestamp with time zone   DEFAULT now() NOT NULL,
  box_id                    bigint,
  product_weight            numeric(12,3),
  extra_weight              numeric(12,3),
  origin_unit_price         numeric(12,2),
  barcode                   text,
  extra_origin_unit_price   numeric(12,2),
  additional_charges_cost   numeric,
  held_for_name             text,
  held_for_phone            text,
  held_for_phone_normalized text,
  hold_note                 text,
  held_by                   text,
  held_at                   timestamp with time zone,
  hold_expires_at           timestamp with time zone,
  deleted_at                timestamp with time zone,
  deleted_by                text
);

CREATE INDEX thrift_stocks_tenant_reserved_phone_idx ON public.thrift_stocks (tenant_id, held_for_phone_normalized)
  WHERE status = 'RESERVED'::public.thrift_stock_status;

CREATE INDEX thrift_stocks_tenant_status_created_at_idx ON public.thrift_stocks (tenant_id, status, created_at DESC);

CREATE INDEX thrift_stocks_name_trgm_idx ON public.thrift_stocks USING gin (name public.gin_trgm_ops);

CREATE INDEX thrift_stocks_brand_trgm_idx ON public.thrift_stocks USING gin (brand_name public.gin_trgm_ops);

CREATE INDEX thrift_stocks_barcode_trgm_idx ON public.thrift_stocks USING gin (barcode public.gin_trgm_ops);

CREATE INDEX thrift_stocks_tenant_condition_created_at_idx ON public.thrift_stocks (tenant_id, condition, created_at DESC);

CREATE INDEX thrift_stocks_tenant_created_at_idx ON public.thrift_stocks (tenant_id, created_at DESC);

CREATE INDEX thrift_stocks_tenant_deleted_at_idx ON public.thrift_stocks (tenant_id, deleted_at)
  WHERE deleted_at IS NULL;

CREATE TRIGGER thrift_stocks_enforce_hold_metadata_trg
  BEFORE INSERT OR UPDATE OF status, held_for_phone, held_for_phone_normalized, held_at ON public.thrift_stocks
  FOR EACH ROW
  EXECUTE FUNCTION public.thrift_stocks_enforce_hold_metadata();

CREATE TRIGGER trg_release_thrift_barcode_on_stock_delete
  AFTER DELETE ON public.thrift_stocks
  FOR EACH ROW
  EXECUTE FUNCTION public.release_thrift_barcode_on_stock_delete();

CREATE TRIGGER trg_thrift_stock_loss_ledger
  AFTER UPDATE ON public.thrift_stocks
  FOR EACH ROW
  EXECUTE FUNCTION public.log_thrift_stock_loss_ledger();

CREATE TRIGGER trg_thrift_stocks_updated_at
  BEFORE UPDATE ON public.thrift_stocks
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY select_thrift_stocks ON public.thrift_stocks
  FOR SELECT
  TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE ((m.tenant_id = thrift_stocks.tenant_id) AND (lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.is_active = true)))));

CREATE POLICY write_thrift_stocks ON public.thrift_stocks
  TO authenticated
  USING (public.membership_has_module_action(tenant_id, 'thrift_stock'::text, 'edit'::text));

COMMENT ON COLUMN public.thrift_stocks.name IS 'Optional display name for the stock item.';

COMMENT ON COLUMN public.thrift_stocks.held_for_phone_normalized IS 'Digits-only hold key (normalize_thrift_phone). Required when status=RESERVED; sale convert requires invoice phone match.';

COMMENT ON COLUMN public.thrift_stocks.hold_expires_at IS 'Optional advisory expiry (v1). No auto-release job.';

ALTER SEQUENCE public.thrift_stocks_id_seq OWNED BY public.thrift_stocks.id;

ALTER TABLE public.thrift_stocks
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.thrift_stocks
  ADD CONSTRAINT thrift_stocks_barcode_tenant_unique UNIQUE (tenant_id, barcode);

ALTER TABLE public.thrift_stocks
  ADD CONSTRAINT thrift_stocks_box_id_fkey FOREIGN KEY (box_id) REFERENCES public.thrift_boxes(id) ON DELETE SET NULL;

ALTER TABLE public.thrift_stocks
  ADD CONSTRAINT thrift_stocks_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.thrift_categories(id);

ALTER TABLE public.thrift_stocks
  ADD CONSTRAINT thrift_stocks_extra_origin_purchase_expense_check CHECK (extra_origin_unit_price >= 0::numeric);

ALTER TABLE public.thrift_stocks
  ADD CONSTRAINT thrift_stocks_extra_weight_check CHECK (extra_weight >= 0::numeric);

ALTER TABLE public.thrift_stocks
  ADD CONSTRAINT thrift_stocks_origin_purchase_price_check CHECK (origin_unit_price >= 0::numeric);

ALTER TABLE public.thrift_stocks
  ADD CONSTRAINT thrift_stocks_pkey PRIMARY KEY (id);

ALTER TABLE public.thrift_stocks
  ADD CONSTRAINT thrift_stocks_product_weight_check CHECK (product_weight >= 0::numeric);

ALTER TABLE public.thrift_stocks
  ADD CONSTRAINT thrift_stocks_quantity_check CHECK (quantity >= 0);

ALTER TABLE public.thrift_stocks
  ADD CONSTRAINT thrift_stocks_shelf_id_fkey FOREIGN KEY (shelf_id) REFERENCES public.thrift_shelves(id);

ALTER TABLE public.thrift_stocks
  ADD CONSTRAINT thrift_stocks_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.thrift_shipments(id) ON DELETE CASCADE;

ALTER TABLE public.thrift_stocks
  ADD CONSTRAINT thrift_stocks_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

ALTER TABLE public.thrift_stocks
  ADD CONSTRAINT thrift_stocks_type_id_fkey FOREIGN KEY (type_id) REFERENCES public.thrift_types(id);

GRANT ALL ON public.thrift_stocks TO anon;

GRANT ALL ON public.thrift_stocks TO authenticated;

GRANT ALL ON public.thrift_stocks TO service_role;