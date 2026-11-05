CREATE TABLE public.customer_group_shop_profiles (
  id                                   bigint                   GENERATED ALWAYS AS IDENTITY NOT NULL,
  tenant_id                            bigint                   NOT NULL,
  customer_group_id                    bigint                   NOT NULL,
  is_active                            boolean                  DEFAULT true NOT NULL,
  default_can_browse                   boolean                  DEFAULT true NOT NULL,
  default_can_add_to_cart              boolean                  DEFAULT true NOT NULL,
  default_can_place_order              boolean                  DEFAULT true NOT NULL,
  default_can_negotiate                boolean                  DEFAULT false NOT NULL,
  default_can_view_quantity            boolean                  DEFAULT true NOT NULL,
  default_can_set_dropship_price       boolean                  DEFAULT false NOT NULL,
  created_at                           timestamp with time zone DEFAULT now() NOT NULL,
  updated_at                           timestamp with time zone DEFAULT now() NOT NULL,
  default_can_see_buy_price            boolean                  DEFAULT false NOT NULL,
  default_can_see_sell_price           boolean                  DEFAULT false NOT NULL,
  default_can_see_resell_minimum_price boolean                  DEFAULT true NOT NULL
);

CREATE TRIGGER trg_customer_group_shop_profiles_updated_at
  BEFORE UPDATE ON public.customer_group_shop_profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.set_customer_group_shop_profiles_updated_at();

CREATE POLICY cg_profiles_select_tenant_member ON public.customer_group_shop_profiles
  FOR SELECT
  USING ((tenant_id IN ( SELECT tm.tenant_id
   FROM public.memberships tm
  WHERE ((lower(TRIM(BOTH FROM tm.email)) = public.current_user_email()) AND (tm.is_active = true)))));

CREATE POLICY cg_profiles_superadmin_all ON public.customer_group_shop_profiles
  USING ((EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE ((lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.role = 'superadmin'::public.app_role) AND (m.is_active = true)))));

CREATE POLICY cg_profiles_write_tenant_admin_staff ON public.customer_group_shop_profiles
  USING ((tenant_id IN ( SELECT m.tenant_id
   FROM public.memberships m
  WHERE ((lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.role = ANY (ARRAY['admin'::public.app_role, 'staff'::public.app_role])) AND (m.is_active = true)))));

ALTER TABLE public.customer_group_shop_profiles
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.customer_group_shop_profiles
  ADD CONSTRAINT customer_group_shop_profiles_pkey PRIMARY KEY (id);

ALTER TABLE public.customer_group_shop_profiles
  ADD CONSTRAINT customer_group_shop_profiles_unique_tenant_group UNIQUE (tenant_id, customer_group_id);

ALTER TABLE public.customer_group_shop_profiles
  ADD CONSTRAINT customer_group_shop_profiles_customer_group_id_fkey FOREIGN KEY (customer_group_id) REFERENCES public.customer_groups(id) ON DELETE CASCADE;

ALTER TABLE public.customer_group_shop_profiles
  ADD CONSTRAINT customer_group_shop_profiles_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.customer_group_shop_profiles TO anon;

GRANT ALL ON public.customer_group_shop_profiles TO authenticated;

GRANT ALL ON public.customer_group_shop_profiles TO service_role;