CREATE TABLE public.shop_customer_group_access (
  id                           bigint                   GENERATED ALWAYS AS IDENTITY NOT NULL,
  shop_id                      bigint                   NOT NULL,
  customer_group_id            bigint                   NOT NULL,
  status                       boolean                  DEFAULT true NOT NULL,
  can_browse                   boolean,
  can_add_to_cart              boolean,
  can_place_order              boolean,
  can_negotiate                boolean,
  can_view_quantity            boolean,
  can_set_dropship_price       boolean,
  price_tier_code              text,
  credit_limit_amount          numeric(12,4)            DEFAULT NULL::numeric,
  credit_limit_currency_id     bigint,
  created_at                   timestamp with time zone DEFAULT now() NOT NULL,
  updated_at                   timestamp with time zone DEFAULT now() NOT NULL,
  can_see_buy_price            boolean,
  can_see_sell_price           boolean,
  can_see_resell_minimum_price boolean
);

CREATE TRIGGER trg_shop_customer_group_access_updated_at
  BEFORE UPDATE ON public.shop_customer_group_access
  FOR EACH ROW
  EXECUTE FUNCTION public.set_shop_customer_group_access_updated_at();

CREATE POLICY shop_cg_access_superadmin_all ON public.shop_customer_group_access
  USING ((EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE ((lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.role = 'superadmin'::public.app_role) AND (m.is_active = true)))));

CREATE POLICY shop_cg_access_select_tenant_member ON public.shop_customer_group_access
  FOR SELECT
  USING ((EXISTS ( SELECT 1
   FROM (public.shops s
     JOIN public.memberships tm ON ((tm.tenant_id = s.tenant_id)))
  WHERE ((s.id = shop_customer_group_access.shop_id) AND (lower(TRIM(BOTH FROM tm.email)) = public.current_user_email()) AND (tm.is_active = true)))));

CREATE POLICY shop_cg_access_write_tenant_admin_staff ON public.shop_customer_group_access
  USING ((EXISTS ( SELECT 1
   FROM public.shops s
  WHERE ((s.id = shop_customer_group_access.shop_id) AND public.membership_has_module_action(s.tenant_id, 'shop_permissions'::text, 'configure'::text)))))
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.shops s
  WHERE ((s.id = shop_customer_group_access.shop_id) AND public.membership_has_module_action(s.tenant_id, 'shop_permissions'::text, 'configure'::text)))));

ALTER TABLE public.shop_customer_group_access
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.shop_customer_group_access
  ADD CONSTRAINT shop_customer_group_access_credit_limit_currency CHECK ((credit_limit_amount IS NULL) = (credit_limit_currency_id IS NULL));

ALTER TABLE public.shop_customer_group_access
  ADD CONSTRAINT shop_customer_group_access_credit_limit_currency_id_fkey FOREIGN KEY (credit_limit_currency_id) REFERENCES public.global_currencies(id);

ALTER TABLE public.shop_customer_group_access
  ADD CONSTRAINT shop_customer_group_access_customer_group_id_fkey FOREIGN KEY (customer_group_id) REFERENCES public.customer_groups(id) ON DELETE CASCADE;

ALTER TABLE public.shop_customer_group_access
  ADD CONSTRAINT shop_customer_group_access_pkey PRIMARY KEY (id);

ALTER TABLE public.shop_customer_group_access
  ADD CONSTRAINT shop_customer_group_access_unique_shop_group UNIQUE (shop_id, customer_group_id);

ALTER TABLE public.shop_customer_group_access
  ADD CONSTRAINT shop_customer_group_access_shop_id_fkey FOREIGN KEY (shop_id) REFERENCES public.shops(id) ON DELETE CASCADE;

GRANT ALL ON public.shop_customer_group_access TO anon;

GRANT ALL ON public.shop_customer_group_access TO authenticated;

GRANT ALL ON public.shop_customer_group_access TO service_role;