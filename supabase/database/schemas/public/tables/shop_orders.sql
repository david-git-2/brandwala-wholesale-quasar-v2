CREATE TABLE public.shop_orders (
  id                                   bigint                        GENERATED ALWAYS AS IDENTITY NOT NULL,
  tenant_id                            bigint                        NOT NULL,
  shop_id                              bigint                        NOT NULL,
  customer_group_id                    bigint,
  cart_id                              bigint,
  order_no                             text                          NOT NULL,
  name                                 text                          NOT NULL,
  shop_type_snapshot                   public.shop_type_enum         NOT NULL,
  order_mode_snapshot                  public.shop_order_mode_enum   NOT NULL,
  is_negotiable_snapshot               boolean                       DEFAULT false NOT NULL,
  status                               public.shop_order_status      DEFAULT 'submitted'::public.shop_order_status NOT NULL,
  negotiate_round                      integer                       DEFAULT 0 NOT NULL,
  cargo_rate                           numeric(12,4),
  conversion_rate                      numeric(12,4),
  profit_rate                          numeric(12,4),
  recipient_name                       text,
  recipient_phone                      text,
  shipping_address                     text,
  profile_id                           bigint,
  placed_at                            timestamp with time zone,
  fulfilled_at                         timestamp with time zone,
  global_invoice_id                    bigint,
  created_by_email                     text                          NOT NULL,
  created_at                           timestamp with time zone      DEFAULT now() NOT NULL,
  updated_at                           timestamp with time zone      DEFAULT now() NOT NULL,
  cod_charge_amount                    numeric(12,2)                 DEFAULT 0 NOT NULL,
  delivery_charge_amount               numeric(12,2)                 DEFAULT 0 NOT NULL,
  print_charge_amount                  numeric(12,2)                 DEFAULT 0 NOT NULL,
  packing_charge_amount                numeric(12,2)                 DEFAULT 0 NOT NULL,
  discount_amount                      numeric(12,2)                 DEFAULT 0 NOT NULL,
  is_prepaid_snapshot                  boolean                       DEFAULT false NOT NULL,
  delivery_instructions                text,
  deduct_charges_from_margin           boolean                       DEFAULT false NOT NULL,
  deduct_cod_from_margin               boolean                       DEFAULT false NOT NULL,
  deduct_delivery_from_margin          boolean                       DEFAULT false NOT NULL,
  deduct_print_from_margin             boolean                       DEFAULT false NOT NULL,
  deduct_packing_from_margin           boolean                       DEFAULT false NOT NULL,
  recipient_phone_secondary            text,
  shipping_district                    text,
  shipping_thana                       text,
  cod_collect_amount                   numeric(15,2),
  package_weight_kg                    numeric(8,2),
  sender_name                          text,
  pickup_phone                         text,
  pickup_address                       text,
  allow_open_box                       boolean                       DEFAULT false,
  driver_notes                         text,
  courier_service_id                   uuid,
  courier_name                         text,
  courier_awb_number                   text,
  tracking_url                         text,
  delivered_at                         timestamp with time zone,
  returned_at                          timestamp with time zone,
  default_sender_name                  text,
  default_pickup_phone                 text,
  default_pickup_address               text,
  default_payout_account_type          text,
  default_payout_account_info          text,
  package_weight_band                  text                          DEFAULT 'under_1kg'::text,
  item_category                        text,
  parcel_description                   text,
  courier_order_ref                    text,
  delivery_zone                        text,
  payout_account_type                  text                          DEFAULT 'bank'::text,
  payout_account_info                  text,
  delivery_instruction_notes           text,
  courier_tracking_number              text,
  courier_consignment_id               text,
  courier_cost_amount                  numeric(12,2)                 DEFAULT 0.00,
  middle_man_reference                 text,
  courier_remittance_ref               text,
  courier_bank_trx_id                  text,
  replacement_of_order_id              bigint,
  return_charge_amount                 numeric(12,2)                 DEFAULT 0.00,
  deduct_return_charge_from_middle_man boolean                       DEFAULT true,
  recipient_profile_id                 bigint,
  return_sub_state                     text,
  return_override_reason               text,
  return_ref                           text,
  collection_source                    public.collection_source_type,
  payout_settlement_status             text,
  profit_basis                         text                          DEFAULT 'total_cost'::text,
  first_offer_rate                     numeric,
  final_offer_rate                     numeric,
  parent_tenant_id                     bigint,
  recipient_call_attempt_count         integer                       DEFAULT 0 NOT NULL,
  recipient_verified_at                timestamp with time zone,
  cancel_reason                        text,
  auto_gifts_applied_at                timestamp with time zone,
  auto_gifts_apply_result              jsonb
);

CREATE UNIQUE INDEX shop_orders_order_no_unique_idx ON public.shop_orders (tenant_id, order_no);

CREATE INDEX shop_orders_recipient_profile_id_idx ON public.shop_orders (recipient_profile_id);

CREATE INDEX idx_shop_orders_parent_tenant_created_at ON public.shop_orders (parent_tenant_id, created_at DESC);

CREATE INDEX idx_shop_orders_parent_tenant_id ON public.shop_orders (parent_tenant_id);

CREATE UNIQUE INDEX idx_shop_orders_tenant_return_ref ON public.shop_orders (tenant_id, return_ref)
  WHERE return_ref IS NOT NULL;

CREATE TRIGGER trg_restock_dropship_order_on_delete
  BEFORE DELETE ON public.shop_orders
  FOR EACH ROW
  EXECUTE FUNCTION public.restock_dropship_order_on_delete();

CREATE TRIGGER trg_shop_order_write_preorder_demand
  AFTER UPDATE ON public.shop_orders
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_fn_shop_order_write_preorder_demand();

CREATE TRIGGER trg_shop_orders_set_parent_tenant_id
  BEFORE INSERT OR UPDATE OF tenant_id ON public.shop_orders
  FOR EACH ROW
  EXECUTE FUNCTION public.set_shop_parent_tenant_id();

CREATE TRIGGER trg_shop_orders_sync_collection_source
  BEFORE INSERT OR UPDATE OF global_invoice_id ON public.shop_orders
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_shop_order_collection_source_from_invoice();

CREATE TRIGGER trg_shop_orders_updated_at
  BEFORE UPDATE ON public.shop_orders
  FOR EACH ROW
  EXECUTE FUNCTION public.set_shop_order_updated_at();

CREATE POLICY shop_orders_customer_owner ON public.shop_orders
  USING (public.is_cart_owner(customer_group_id, tenant_id))
  WITH CHECK (public.is_cart_owner(customer_group_id, tenant_id));

CREATE POLICY shop_orders_staff_all ON public.shop_orders
  USING (public.is_tenant_staff(tenant_id))
  WITH CHECK (public.is_tenant_staff(tenant_id));

COMMENT ON COLUMN public.shop_orders.collection_source IS 'Dropship: recipient = courier COD remittance; billing_profile = merchant prepaid. Not the merchant invoice collection_source.';

COMMENT ON COLUMN public.shop_orders.payout_settlement_status IS 'Merchant profit settlement: unpaid | partial | paid (order-level)';

ALTER TABLE public.shop_orders
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.shop_orders
  ADD CONSTRAINT fk_shop_orders_courier_service FOREIGN KEY (courier_service_id) REFERENCES public.courier_services(id) ON DELETE SET NULL;

ALTER TABLE public.shop_orders
  ADD CONSTRAINT shop_orders_cart_id_fkey FOREIGN KEY (cart_id) REFERENCES public.shop_carts(id) ON DELETE SET NULL;

ALTER TABLE public.shop_orders
  ADD CONSTRAINT shop_orders_customer_group_id_fkey FOREIGN KEY (customer_group_id) REFERENCES public.customer_groups(id) ON DELETE SET NULL;

ALTER TABLE public.shop_orders
  ADD CONSTRAINT shop_orders_delivery_zone_check CHECK (delivery_zone = ANY (ARRAY['inside_dhaka'::text, 'outside_dhaka'::text]));

ALTER TABLE public.shop_orders
  ADD CONSTRAINT shop_orders_global_invoice_id_fkey FOREIGN KEY (global_invoice_id) REFERENCES public.bills(id) ON DELETE SET NULL;

ALTER TABLE public.shop_orders
  ADD CONSTRAINT shop_orders_payout_settlement_status_check
    CHECK (payout_settlement_status IS NULL OR (payout_settlement_status = ANY (ARRAY['unpaid'::text, 'partial'::text, 'paid'::text])));

ALTER TABLE public.shop_orders
  ADD CONSTRAINT shop_orders_pkey PRIMARY KEY (id);

ALTER TABLE public.shop_orders
  ADD CONSTRAINT shop_orders_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id) ON DELETE SET NULL;

ALTER TABLE public.shop_orders
  ADD CONSTRAINT shop_orders_profit_basis_check CHECK (profit_basis = ANY (ARRAY['purchase'::text, 'total_cost'::text]));

ALTER TABLE public.shop_orders
  ADD CONSTRAINT shop_orders_recipient_profile_id_fkey FOREIGN KEY (recipient_profile_id) REFERENCES public.recipient_profiles(id) ON DELETE RESTRICT;

ALTER TABLE public.shop_orders
  ADD CONSTRAINT shop_orders_replacement_of_order_id_fkey FOREIGN KEY (replacement_of_order_id) REFERENCES public.shop_orders(id);

ALTER TABLE public.shop_orders
  ADD CONSTRAINT shop_orders_return_sub_state_check CHECK (return_sub_state = ANY (ARRAY['return_requested'::text, 'return_finalized'::text]));

ALTER TABLE public.shop_orders
  ADD CONSTRAINT shop_orders_shop_id_fkey FOREIGN KEY (shop_id) REFERENCES public.shops(id) ON DELETE CASCADE;

ALTER TABLE public.shop_orders
  ADD CONSTRAINT shop_orders_parent_tenant_id_fkey FOREIGN KEY (parent_tenant_id) REFERENCES public.tenants(id) ON DELETE SET NULL;

ALTER TABLE public.shop_orders
  ADD CONSTRAINT shop_orders_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.shop_orders TO anon;

GRANT ALL ON public.shop_orders TO authenticated;

GRANT ALL ON public.shop_orders TO service_role;