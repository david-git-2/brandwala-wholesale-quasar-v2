CREATE TABLE public.shop_listing_group_hides (
  id                bigint                   GENERATED ALWAYS AS IDENTITY NOT NULL,
  shop_id           bigint                   NOT NULL,
  listing_id        bigint                   NOT NULL,
  customer_group_id bigint                   NOT NULL,
  created_at        timestamp with time zone DEFAULT now() NOT NULL
);

CREATE INDEX idx_shop_listing_group_hides_shop_group ON public.shop_listing_group_hides (shop_id, customer_group_id);

CREATE POLICY shop_listing_group_hides_superadmin_all ON public.shop_listing_group_hides
  USING ((EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE ((lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.role = 'superadmin'::public.app_role) AND (m.is_active = true)))));

CREATE POLICY shop_listing_group_hides_select_tenant_member ON public.shop_listing_group_hides
  FOR SELECT
  USING ((EXISTS ( SELECT 1
   FROM (public.shops s
     JOIN public.memberships tm ON ((tm.tenant_id = s.tenant_id)))
  WHERE ((s.id = shop_listing_group_hides.shop_id) AND (lower(TRIM(BOTH FROM tm.email)) = public.current_user_email()) AND (tm.is_active = true)))));

CREATE POLICY shop_listing_group_hides_write_tenant_admin_staff ON public.shop_listing_group_hides
  USING ((EXISTS ( SELECT 1
   FROM public.shops s
  WHERE ((s.id = shop_listing_group_hides.shop_id) AND public.membership_has_module_action(s.tenant_id, 'shop_permissions'::text, 'configure'::text)))))
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.shops s
  WHERE ((s.id = shop_listing_group_hides.shop_id) AND public.membership_has_module_action(s.tenant_id, 'shop_permissions'::text, 'configure'::text)))));

COMMENT ON TABLE public.shop_listing_group_hides IS 'Dropship: row means this group cannot see the listing. No row = shown.';

ALTER TABLE public.shop_listing_group_hides
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.shop_listing_group_hides
  ADD CONSTRAINT shop_listing_group_hides_customer_group_id_fkey FOREIGN KEY (customer_group_id) REFERENCES public.customer_groups(id) ON DELETE CASCADE;

ALTER TABLE public.shop_listing_group_hides
  ADD CONSTRAINT shop_listing_group_hides_listing_group_unique UNIQUE (listing_id, customer_group_id);

ALTER TABLE public.shop_listing_group_hides
  ADD CONSTRAINT shop_listing_group_hides_pkey PRIMARY KEY (id);

ALTER TABLE public.shop_listing_group_hides
  ADD CONSTRAINT shop_listing_group_hides_listing_id_fkey FOREIGN KEY (listing_id) REFERENCES public.shop_product_listings(id) ON DELETE CASCADE;

ALTER TABLE public.shop_listing_group_hides
  ADD CONSTRAINT shop_listing_group_hides_shop_id_fkey FOREIGN KEY (shop_id) REFERENCES public.shops(id) ON DELETE CASCADE;

GRANT ALL ON public.shop_listing_group_hides TO anon;

GRANT ALL ON public.shop_listing_group_hides TO authenticated;

GRANT ALL ON public.shop_listing_group_hides TO service_role;