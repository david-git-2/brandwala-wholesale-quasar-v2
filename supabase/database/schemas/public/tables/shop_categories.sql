CREATE TABLE public.shop_categories (
  id          bigint                   GENERATED ALWAYS AS IDENTITY NOT NULL,
  tenant_id   bigint                   NOT NULL,
  name        character varying(255)   NOT NULL,
  slug        character varying(255)   NOT NULL,
  description text,
  icon        character varying(100)   DEFAULT 'category'::character varying,
  is_active   boolean                  DEFAULT true NOT NULL,
  created_at  timestamp with time zone DEFAULT now() NOT NULL,
  updated_at  timestamp with time zone DEFAULT now() NOT NULL
);

CREATE INDEX idx_shop_categories_tenant ON public.shop_categories (tenant_id, is_active);

CREATE POLICY shop_categories_select_policy ON public.shop_categories
  FOR SELECT
  TO authenticated
  USING (((is_active = true) OR public.is_superadmin() OR (EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE ((m.tenant_id = shop_categories.tenant_id) AND (lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.is_active = true))))));

CREATE POLICY shop_categories_service_role_policy ON public.shop_categories
  TO service_role
  USING (true)
  WITH CHECK (true);

CREATE POLICY shop_categories_staff_manage_policy ON public.shop_categories
  TO authenticated
  USING ((public.is_superadmin() OR (EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE
    ((m.tenant_id = shop_categories.tenant_id) AND (lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.is_active = true) AND (m.role = ANY
    (ARRAY['admin'::public.app_role, 'staff'::public.app_role, 'superadmin'::public.app_role])))))))
  WITH CHECK ((public.is_superadmin() OR (EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE
    ((m.tenant_id = shop_categories.tenant_id) AND (lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.is_active = true) AND (m.role = ANY
    (ARRAY['admin'::public.app_role, 'staff'::public.app_role, 'superadmin'::public.app_role])))))));

ALTER TABLE public.shop_categories
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.shop_categories
  ADD CONSTRAINT shop_categories_pkey PRIMARY KEY (id);

ALTER TABLE public.shop_categories
  ADD CONSTRAINT uq_shop_categories_tenant_slug UNIQUE (tenant_id, slug);

ALTER TABLE public.shop_categories
  ADD CONSTRAINT shop_categories_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.shop_categories TO anon;

GRANT ALL ON public.shop_categories TO authenticated;

GRANT ALL ON public.shop_categories TO service_role;