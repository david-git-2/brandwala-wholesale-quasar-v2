CREATE TABLE public.shops (
  id                                   bigint                      GENERATED ALWAYS AS IDENTITY NOT NULL,
  tenant_id                            bigint                      NOT NULL,
  name                                 text                        NOT NULL,
  slug                                 text                        NOT NULL,
  shop_type                            public.shop_type_enum       NOT NULL,
  vendor_code                          text,
  order_mode                           public.shop_order_mode_enum NOT NULL,
  is_negotiable                        boolean                     DEFAULT false NOT NULL,
  show_stock_quantity                  boolean                     DEFAULT true NOT NULL,
  default_currency_id                  bigint,
  global_stock_type_id                 bigint,
  is_active                            boolean                     DEFAULT true NOT NULL,
  created_at                           timestamp with time zone    DEFAULT now() NOT NULL,
  updated_at                           timestamp with time zone    DEFAULT now() NOT NULL,
  allow_delivery                       boolean                     DEFAULT false NOT NULL,
  buy_currency_id                      bigint                      NOT NULL,
  sell_currency_id                     bigint                      NOT NULL,
  pricing_method                       text                        NOT NULL,
  markup_percentage                    numeric(5,2)                DEFAULT 0 NOT NULL,
  quantity_display_mode                text                        NOT NULL,
  default_print_charge_amount          numeric(12,2)               DEFAULT 0 NOT NULL,
  default_packing_charge_amount        numeric(12,2)               DEFAULT 0 NOT NULL,
  deduct_charges_from_margin           boolean                     DEFAULT false NOT NULL,
  vendor_filters                       jsonb,
  deduct_print_from_margin             boolean                     DEFAULT false NOT NULL,
  deduct_packing_from_margin           boolean                     DEFAULT false NOT NULL,
  deduct_return_charge_from_middle_man boolean                     DEFAULT true,
  description                          text,
  category_ids                         bigint[]                    DEFAULT '{}'::bigint[],
  deduct_cod_from_margin               boolean                     DEFAULT false NOT NULL,
  deduct_delivery_from_margin          boolean                     DEFAULT false NOT NULL,
  deleted_at                           timestamp with time zone,
  deleted_by                           text,
  min_available_units                  integer                     DEFAULT 0 NOT NULL,
  parent_tenant_id                     bigint,
  display_quantity_add                 integer                     DEFAULT 6 NOT NULL
);

CREATE INDEX idx_shops_parent_tenant_id ON public.shops (parent_tenant_id);

CREATE INDEX idx_shops_category_ids ON public.shops USING gin (category_ids);

CREATE UNIQUE INDEX shops_unique_live_slug ON public.shops (tenant_id, slug)
  WHERE deleted_at IS NULL;

CREATE INDEX shops_tenant_live_idx ON public.shops (tenant_id)
  WHERE deleted_at IS NULL;

CREATE TRIGGER trg_shops_derive_is_negotiable
  BEFORE INSERT OR UPDATE OF shop_type, is_negotiable ON public.shops
  FOR EACH ROW
  EXECUTE FUNCTION public.shops_derive_is_negotiable();

CREATE TRIGGER trg_shops_set_parent_tenant_id
  BEFORE INSERT OR UPDATE OF tenant_id ON public.shops
  FOR EACH ROW
  EXECUTE FUNCTION public.set_shop_parent_tenant_id();

CREATE TRIGGER trg_shops_updated_at
  BEFORE UPDATE ON public.shops
  FOR EACH ROW
  EXECUTE FUNCTION public.set_shops_updated_at();

CREATE POLICY shops_delete_tenant_admin ON public.shops
  FOR DELETE
  USING (public.membership_has_module_action(tenant_id, 'shop_config'::text, 'delete'::text));

CREATE POLICY shops_insert_tenant_admin_staff ON public.shops
  FOR INSERT
  WITH CHECK (public.membership_has_module_action(tenant_id, 'shop_config'::text, 'create'::text));

CREATE POLICY shops_select_customer_group ON public.shops
  FOR SELECT
  USING (((is_active = true) AND public.customer_can_select_shop(id, tenant_id)));

CREATE POLICY shops_select_tenant_member ON public.shops
  FOR SELECT
  USING ((tenant_id IN ( SELECT tm.tenant_id
   FROM public.memberships tm
  WHERE ((lower(TRIM(BOTH FROM tm.email)) = public.current_user_email()) AND (tm.is_active = true)))));

CREATE POLICY shops_superadmin_all ON public.shops
  USING ((EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE ((lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.role = 'superadmin'::public.app_role) AND (m.is_active = true)))));

CREATE POLICY shops_update_tenant_admin_staff ON public.shops
  FOR UPDATE
  USING (public.membership_has_module_action(tenant_id, 'shop_config'::text, 'edit'::text));

ALTER TABLE public.shops
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.shops
  ADD CONSTRAINT shops_buy_currency_id_fkey FOREIGN KEY (buy_currency_id) REFERENCES public.global_currencies(id);

ALTER TABLE public.shops
  ADD CONSTRAINT shops_default_currency_id_fkey FOREIGN KEY (default_currency_id) REFERENCES public.global_currencies(id);

ALTER TABLE public.shops
  ADD CONSTRAINT shops_display_quantity_add_check CHECK (display_quantity_add >= 0);

ALTER TABLE public.shops
  ADD CONSTRAINT shops_dropship_not_negotiable CHECK (shop_type <> 'dropship'::public.shop_type_enum OR is_negotiable = false);

ALTER TABLE public.shops
  ADD CONSTRAINT shops_markup_percentage_check CHECK (markup_percentage >= 0::numeric);

ALTER TABLE public.shops
  ADD CONSTRAINT shops_min_available_units_check CHECK (min_available_units >= 0);

ALTER TABLE public.shops
  ADD CONSTRAINT shops_pkey PRIMARY KEY (id);

ALTER TABLE public.shops
  ADD CONSTRAINT shops_pricing_method_check CHECK (pricing_method = ANY (ARRAY['direct_cost'::text, 'markup'::text]));

ALTER TABLE public.shops
  ADD CONSTRAINT shops_quantity_display_mode_check CHECK (quantity_display_mode = ANY (ARRAY['original'::text, 'custom_override'::text]));

ALTER TABLE public.shops
  ADD CONSTRAINT shops_sell_currency_id_fkey FOREIGN KEY (sell_currency_id) REFERENCES public.global_currencies(id);

ALTER TABLE public.shops
  ADD CONSTRAINT shops_sell_currency_match CHECK (sell_currency_id = default_currency_id);

ALTER TABLE public.shops
  ADD CONSTRAINT shops_vendor_catalog_requires_vendor_code CHECK (shop_type <> 'vendor_catalog'::public.shop_type_enum OR is_active = false OR vendor_code IS
    NOT NULL OR vendor_filters IS NOT NULL AND jsonb_array_length(vendor_filters) > 0);

ALTER TABLE public.shops
  ADD CONSTRAINT shops_parent_tenant_id_fkey FOREIGN KEY (parent_tenant_id) REFERENCES public.tenants(id) ON DELETE SET NULL;

ALTER TABLE public.shops
  ADD CONSTRAINT shops_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.shops TO anon;

GRANT ALL ON public.shops TO authenticated;

GRANT ALL ON public.shops TO service_role;