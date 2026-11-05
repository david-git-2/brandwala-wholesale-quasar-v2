CREATE TABLE public.thrift_shipments (
  id                        bigint                   DEFAULT nextval('public.thrift_shipments_id_seq'::regclass) NOT NULL,
  tenant_id                 bigint                   NOT NULL,
  name                      text                     NOT NULL,
  cargo_conversion_rate     numeric(12,4),
  cargo_rate                numeric(12,4),
  product_conversion_rate   numeric(12,4),
  inserted_by               text                     NOT NULL,
  created_at                timestamp with time zone DEFAULT now() NOT NULL,
  updated_at                timestamp with time zone DEFAULT now() NOT NULL,
  purchase_currency_id      bigint                   NOT NULL,
  cost_currency_id          bigint                   NOT NULL,
  total_cargo_weight_kg     numeric,
  labor_total_cost          numeric,
  transportation_total_cost numeric,
  default_markup_rate       numeric,
  washing_total_cost        numeric,
  marketing_tag_config      jsonb                    DEFAULT
    '{"show_logo": true, "brand_name": "", "show_brand_name": true, "show_core_sizes": true, "show_listed_sell": true, "show_barcode_text": true}'::jsonb NOT NULL
);

CREATE TRIGGER trg_thrift_shipments_updated_at
  BEFORE UPDATE ON public.thrift_shipments
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY select_thrift_shipments ON public.thrift_shipments
  FOR SELECT
  TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE ((m.tenant_id = thrift_shipments.tenant_id) AND (lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.is_active = true)))));

CREATE POLICY write_thrift_shipments ON public.thrift_shipments
  TO authenticated
  USING (public.membership_has_module_action(tenant_id, 'thrift_shipment'::text, 'edit'::text));

COMMENT ON COLUMN public.thrift_shipments.marketing_tag_config IS 'Per-shipment marketing sticker layout: shop brand and field visibility.';

ALTER SEQUENCE public.thrift_shipments_id_seq OWNED BY public.thrift_shipments.id;

ALTER TABLE public.thrift_shipments
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.thrift_shipments
  ADD CONSTRAINT thrift_shipments_cost_currency_id_fkey FOREIGN KEY (cost_currency_id) REFERENCES public.global_currencies(id);

ALTER TABLE public.thrift_shipments
  ADD CONSTRAINT thrift_shipments_pkey PRIMARY KEY (id);

ALTER TABLE public.thrift_shipments
  ADD CONSTRAINT thrift_shipments_purchase_currency_id_fkey FOREIGN KEY (purchase_currency_id) REFERENCES public.global_currencies(id);

ALTER TABLE public.thrift_shipments
  ADD CONSTRAINT thrift_shipments_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.thrift_shipments TO anon;

GRANT ALL ON public.thrift_shipments TO authenticated;

GRANT ALL ON public.thrift_shipments TO service_role;