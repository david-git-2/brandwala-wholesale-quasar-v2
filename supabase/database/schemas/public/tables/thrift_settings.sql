CREATE TABLE public.thrift_settings (
  tenant_id                 bigint                   NOT NULL,
  default_origin_unit_price numeric(12,2)            DEFAULT 0.00 NOT NULL,
  created_at                timestamp with time zone DEFAULT now() NOT NULL,
  updated_at                timestamp with time zone DEFAULT now() NOT NULL,
  hand_tag_unit_cost        numeric,
  hand_tag_unit_currency_id bigint,
  sticker_unit_cost         numeric,
  sticker_unit_currency_id  bigint,
  marketing_tag_config      jsonb                    DEFAULT
    '{"show_logo": true, "brand_name": "", "show_tag_size": true, "show_brand_name": true, "show_core_sizes": true, "show_listed_sell": true, "show_barcode_text": true, "show_additional_sizes": true}'::jsonb NOT NULL,
  return_window_days        integer                  DEFAULT 30 NOT NULL
);

CREATE TRIGGER trg_thrift_settings_updated_at
  BEFORE UPDATE ON public.thrift_settings
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY select_thrift_settings ON public.thrift_settings
  FOR SELECT
  TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE ((m.tenant_id = thrift_settings.tenant_id) AND (lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.is_active = true)))));

CREATE POLICY write_thrift_settings ON public.thrift_settings
  TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE
    ((m.tenant_id = thrift_settings.tenant_id) AND (lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.is_active = true) AND (m.role = ANY
    (ARRAY['admin'::public.app_role, 'staff'::public.app_role]))))));

COMMENT ON COLUMN public.thrift_settings.marketing_tag_config IS 'Per-tenant marketing sticker layout settings.';

COMMENT ON COLUMN public.thrift_settings.return_window_days IS 'Customer RETURN eligibility window (days) from invoice date; 0 = no customer returns';

ALTER TABLE public.thrift_settings
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.thrift_settings
  ADD CONSTRAINT thrift_settings_hand_tag_unit_currency_id_fkey FOREIGN KEY (hand_tag_unit_currency_id) REFERENCES public.global_currencies(id) ON DELETE SET NULL;

ALTER TABLE public.thrift_settings
  ADD CONSTRAINT thrift_settings_return_window_days_check CHECK (return_window_days >= 0);

ALTER TABLE public.thrift_settings
  ADD CONSTRAINT thrift_settings_sticker_unit_currency_id_fkey FOREIGN KEY (sticker_unit_currency_id) REFERENCES public.global_currencies(id) ON DELETE SET NULL;

ALTER TABLE public.thrift_settings
  ADD CONSTRAINT thrift_settings_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

ALTER TABLE public.thrift_settings
  ADD CONSTRAINT thrift_stock_settings_default_purchase_price_check CHECK (default_origin_unit_price >= 0::numeric);

ALTER TABLE public.thrift_settings
  ADD CONSTRAINT thrift_stock_settings_pkey PRIMARY KEY (tenant_id);

GRANT ALL ON public.thrift_settings TO anon;

GRANT ALL ON public.thrift_settings TO authenticated;

GRANT ALL ON public.thrift_settings TO service_role;