CREATE TABLE public.koba_retail_settings (
  id                       bigint                   DEFAULT nextval('public.koba_retail_settings_id_seq'::regclass) NOT NULL,
  tenant_id                bigint                   NOT NULL,
  cod_charge_pct           numeric(5,2)             DEFAULT 1.00,
  gateway_charge_flat      numeric(12,2)            DEFAULT 20.00,
  packing_charge_flat      numeric(12,2)            DEFAULT 37.00,
  invoice_charge_flat      numeric(12,2)            DEFAULT 1.00,
  extra_profit_user_pct    numeric(5,2)             DEFAULT 90.00,
  extra_profit_company_pct numeric(5,2)             DEFAULT 10.00,
  delivery_rates           jsonb                    DEFAULT '{"Dhaka": 100, "default": 110, "Dhaka Sub-Urban": 100}'::jsonb,
  created_at               timestamp with time zone DEFAULT now(),
  updated_at               timestamp with time zone DEFAULT now()
);

CREATE TRIGGER set_koba_retail_settings_updated_at
  BEFORE UPDATE ON public.koba_retail_settings
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_koba_retail_settings_updated_at();

CREATE POLICY "Users can update retail settings for their tenant" ON public.koba_retail_settings
  FOR UPDATE
  TO authenticated
  USING ((public.is_superadmin() OR public.is_tenant_admin(tenant_id)))
  WITH CHECK ((public.is_superadmin() OR public.is_tenant_admin(tenant_id)));

CREATE POLICY "Users can read retail settings for their tenant" ON public.koba_retail_settings
  FOR SELECT
  TO authenticated
  USING ((public.is_superadmin() OR (EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE ((lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.tenant_id = koba_retail_settings.tenant_id) AND (m.is_active = true))))));

ALTER SEQUENCE public.koba_retail_settings_id_seq OWNED BY public.koba_retail_settings.id;

ALTER TABLE public.koba_retail_settings
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.koba_retail_settings
  ADD CONSTRAINT koba_retail_settings_pkey PRIMARY KEY (id);

ALTER TABLE public.koba_retail_settings
  ADD CONSTRAINT koba_retail_settings_tenant_id_key UNIQUE (tenant_id);

ALTER TABLE public.koba_retail_settings
  ADD CONSTRAINT koba_retail_settings_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.koba_retail_settings TO anon;

GRANT ALL ON public.koba_retail_settings TO authenticated;

GRANT ALL ON public.koba_retail_settings TO service_role;