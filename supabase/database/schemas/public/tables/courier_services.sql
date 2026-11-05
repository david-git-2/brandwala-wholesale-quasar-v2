CREATE TABLE public.courier_services (
  id                             uuid                     DEFAULT gen_random_uuid() NOT NULL,
  tenant_id                      bigint,
  code                           text                     NOT NULL,
  name                           text                     NOT NULL,
  is_active                      boolean                  DEFAULT true NOT NULL,
  cod_fee_mode                   text                     DEFAULT 'percent_of_collect'::text NOT NULL,
  cod_fee_percent                numeric(5,2)             DEFAULT 0.00,
  cod_fee_flat_amount            numeric(12,2)            DEFAULT 0.00,
  cod_fee_notes                  text,
  deduct_cod_from_margin_default boolean                  DEFAULT false NOT NULL,
  inside_dhaka_fee               numeric(12,2)            DEFAULT 60.00 NOT NULL,
  outside_dhaka_fee              numeric(12,2)            DEFAULT 120.00 NOT NULL,
  inside_dhaka_return_fee        numeric(12,2)            DEFAULT 30.00,
  outside_dhaka_return_fee       numeric(12,2)            DEFAULT 60.00,
  return_fee_mode                text                     DEFAULT 'flat'::text NOT NULL,
  return_fee_percent             numeric(5,2)             DEFAULT 0.00,
  delivery_attempt_count         integer                  DEFAULT 2 NOT NULL,
  hub_hold_days                  integer                  DEFAULT 3 NOT NULL,
  open_box_default_allowed       boolean                  DEFAULT false NOT NULL,
  notes                          text,
  created_at                     timestamp with time zone DEFAULT now() NOT NULL,
  updated_at                     timestamp with time zone DEFAULT now() NOT NULL,
  tracking_url_template          text,
  wallet_entity_id               bigint                   DEFAULT nextval('public.courier_wallet_entity_id_seq'::regclass) NOT NULL
);

CREATE UNIQUE INDEX uq_courier_services_wallet_entity_id ON public.courier_services (wallet_entity_id);

CREATE TRIGGER trg_courier_services_sync_profile
  AFTER INSERT OR UPDATE ON public.courier_services
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_sync_profile_from_courier_service();

CREATE POLICY courier_services_delete_policy ON public.courier_services
  FOR DELETE
  TO authenticated
  USING
    ((public.is_superadmin() OR (public.membership_has_module_action(public.current_tenant_id(), 'shop_shipping'::text, 'configure'::text) AND ((tenant_id IS NULL) OR (tenant_id =
    public.current_tenant_id())))));

CREATE POLICY courier_services_insert_policy ON public.courier_services
  FOR INSERT
  TO authenticated
  WITH
    CHECK
    ((public.is_superadmin() OR (public.membership_has_module_action(public.current_tenant_id(), 'shop_shipping'::text, 'configure'::text) AND ((tenant_id IS NULL) OR (tenant_id =
    public.current_tenant_id())))));

CREATE POLICY courier_services_update_policy ON public.courier_services
  FOR UPDATE
  TO authenticated
  USING
    ((public.is_superadmin() OR (public.membership_has_module_action(public.current_tenant_id(), 'shop_shipping'::text, 'configure'::text) AND ((tenant_id IS NULL) OR (tenant_id =
    public.current_tenant_id())))))
  WITH
    CHECK
    ((public.is_superadmin() OR (public.membership_has_module_action(public.current_tenant_id(), 'shop_shipping'::text, 'configure'::text) AND ((tenant_id IS NULL) OR (tenant_id =
    public.current_tenant_id())))));

CREATE POLICY courier_services_select_policy ON public.courier_services
  FOR SELECT
  TO authenticated
  USING (((tenant_id IS NULL) OR public.is_superadmin() OR (EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE ((m.tenant_id = courier_services.tenant_id) AND (lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.is_active = true))))));

ALTER TABLE public.courier_services
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.courier_services
  ADD CONSTRAINT courier_services_cod_fee_mode_check CHECK (cod_fee_mode = ANY (ARRAY['none'::text, 'percent_of_collect'::text, 'flat'::text, 'tiered_manual'::text]));

ALTER TABLE public.courier_services
  ADD CONSTRAINT courier_services_code_key UNIQUE (code);

ALTER TABLE public.courier_services
  ADD CONSTRAINT courier_services_pkey PRIMARY KEY (id);

ALTER TABLE public.courier_services
  ADD CONSTRAINT courier_services_return_fee_mode_check CHECK (return_fee_mode = ANY (ARRAY['none'::text, 'percent_of_forward'::text, 'flat'::text, 'tiered_manual'::text]));

ALTER TABLE public.courier_services
  ADD CONSTRAINT courier_services_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.courier_services TO anon;

GRANT ALL ON public.courier_services TO authenticated;

GRANT ALL ON public.courier_services TO service_role;