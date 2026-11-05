CREATE TABLE public.shop_pricing_rules (
  id                         bigint                   GENERATED ALWAYS AS IDENTITY NOT NULL,
  tenant_id                  bigint                   NOT NULL,
  shop_id                    bigint                   NOT NULL,
  markup_percentage          numeric(8,2)             DEFAULT 0.00 NOT NULL,
  is_auto_publish            boolean                  DEFAULT false NOT NULL,
  created_at                 timestamp with time zone DEFAULT now() NOT NULL,
  updated_at                 timestamp with time zone DEFAULT now() NOT NULL,
  default_show_quantity      boolean                  DEFAULT true NOT NULL,
  default_add_quantity       integer                  DEFAULT 0 NOT NULL,
  dropship_markup_percentage numeric(8,2)             DEFAULT 0.00 NOT NULL
);

CREATE TRIGGER trg_shop_pricing_rules_updated_at
  BEFORE UPDATE ON public.shop_pricing_rules
  FOR EACH ROW
  EXECUTE FUNCTION public.set_shop_pricing_rules_updated_at();

CREATE POLICY shop_pricing_rules_select ON public.shop_pricing_rules
  FOR SELECT
  USING ((tenant_id IN ( SELECT tm.tenant_id
   FROM public.memberships tm
  WHERE ((lower(TRIM(BOTH FROM tm.email)) = public.current_user_email()) AND (tm.is_active = true)))));

CREATE POLICY shop_pricing_rules_write ON public.shop_pricing_rules
  USING (public.user_can_manage_shop_tenant(tenant_id))
  WITH CHECK (public.user_can_manage_shop_tenant(tenant_id));

ALTER TABLE public.shop_pricing_rules
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.shop_pricing_rules
  ADD CONSTRAINT shop_pricing_rules_dropship_markup_non_negative CHECK (dropship_markup_percentage >= 0::numeric);

ALTER TABLE public.shop_pricing_rules
  ADD CONSTRAINT shop_pricing_rules_markup_non_negative CHECK (markup_percentage >= 0::numeric);

ALTER TABLE public.shop_pricing_rules
  ADD CONSTRAINT shop_pricing_rules_pkey PRIMARY KEY (id);

ALTER TABLE public.shop_pricing_rules
  ADD CONSTRAINT shop_pricing_rules_unique_shop UNIQUE (shop_id);

ALTER TABLE public.shop_pricing_rules
  ADD CONSTRAINT shop_pricing_rules_shop_id_fkey FOREIGN KEY (shop_id) REFERENCES public.shops(id) ON DELETE CASCADE;

ALTER TABLE public.shop_pricing_rules
  ADD CONSTRAINT shop_pricing_rules_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.shop_pricing_rules TO anon;

GRANT ALL ON public.shop_pricing_rules TO authenticated;

GRANT ALL ON public.shop_pricing_rules TO service_role;