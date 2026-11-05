CREATE TABLE public.product_based_costing_files (
  id                  bigint                        DEFAULT nextval('public.product_based_costing_files_id_seq'::regclass) NOT NULL,
  tenant_id           bigint,
  name                text,
  order_for           text,
  note                text,
  cargo_rate_kg_gbp   numeric(12,4),
  profit_rate         numeric(12,4),
  conversion_rate     numeric(12,6),
  status              text,
  created_at          timestamp with time zone      DEFAULT now() NOT NULL,
  updated_at          timestamp with time zone      DEFAULT now() NOT NULL,
  invoice_id          bigint,
  vendor_code         text,
  market_code         text,
  default_shipment_id bigint,
  vendor_id           bigint,
  profile_id          bigint,
  customer_group_id   bigint,
  vat_rate            numeric(12,4)                 DEFAULT 0,
  offer_pricing_mode  public.pbc_offer_pricing_mode DEFAULT 'landed_cost_plus'::public.pbc_offer_pricing_mode NOT NULL,
  buy_currency_id     bigint                        NOT NULL,
  buy_currency_code   text                          NOT NULL,
  sell_currency_id    bigint                        NOT NULL,
  sell_currency_code  text                          NOT NULL
);

CREATE INDEX product_based_costing_files_customer_group_id_idx ON public.product_based_costing_files (customer_group_id);

CREATE INDEX product_based_costing_files_name_idx ON public.product_based_costing_files (name);

CREATE INDEX product_based_costing_files_vendor_id_idx ON public.product_based_costing_files (vendor_id);

CREATE INDEX product_based_costing_files_vendor_code_idx ON public.product_based_costing_files (vendor_code);

CREATE INDEX product_based_costing_files_tenant_id_idx ON public.product_based_costing_files (tenant_id);

CREATE INDEX product_based_costing_files_tenant_created_at_id_idx ON public.product_based_costing_files (tenant_id, created_at DESC, id DESC);

CREATE INDEX product_based_costing_files_status_idx ON public.product_based_costing_files (status);

CREATE INDEX product_based_costing_files_billing_profile_id_idx ON public.product_based_costing_files (profile_id);

CREATE INDEX product_based_costing_files_market_code_idx ON public.product_based_costing_files (market_code);

CREATE INDEX product_based_costing_files_invoice_id_idx ON public.product_based_costing_files (invoice_id);

CREATE INDEX product_based_costing_files_default_shipment_id_idx ON public.product_based_costing_files (default_shipment_id);

CREATE TRIGGER trg_pbc_file_write_preorder_demand
  AFTER UPDATE ON public.product_based_costing_files
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_fn_pbc_file_write_preorder_demand();

CREATE TRIGGER trg_pbc_files_0_stamp_billing_profile
  BEFORE INSERT OR UPDATE OF customer_group_id ON public.product_based_costing_files
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_fn_pbc_files_stamp_billing_profile();

CREATE TRIGGER trg_pbc_files_auto_tenant_id
  BEFORE INSERT OR UPDATE OF profile_id, tenant_id ON public.product_based_costing_files
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_fn_pbc_files_auto_tenant_id();

CREATE TRIGGER trg_pbc_files_stamp_currency_codes
  BEFORE INSERT OR UPDATE OF buy_currency_id, sell_currency_id ON public.product_based_costing_files
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_fn_pbc_files_stamp_currency_codes();

CREATE TRIGGER trg_product_based_costing_files_set_updated_at
  BEFORE UPDATE ON public.product_based_costing_files
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_product_based_costing_files_sync_vendor_reference_fields
  BEFORE INSERT OR UPDATE ON public.product_based_costing_files
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_vendor_reference_fields();

CREATE POLICY product_based_costing_files_delete ON public.product_based_costing_files
  FOR DELETE
  TO authenticated
  USING (public.can_manage_costing(tenant_id));

CREATE POLICY product_based_costing_files_insert ON public.product_based_costing_files
  FOR INSERT
  TO authenticated
  WITH CHECK (public.can_manage_costing(tenant_id));

CREATE POLICY product_based_costing_files_select ON public.product_based_costing_files
  FOR SELECT
  TO authenticated
  USING (public.can_view_costing_internal(tenant_id));

CREATE POLICY product_based_costing_files_update ON public.product_based_costing_files
  FOR UPDATE
  TO authenticated
  USING (public.can_manage_costing(tenant_id))
  WITH CHECK (public.can_manage_costing(tenant_id));

ALTER SEQUENCE public.product_based_costing_files_id_seq OWNED BY public.product_based_costing_files.id;

ALTER TABLE public.product_based_costing_files
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.product_based_costing_files
  ADD CONSTRAINT product_based_costing_files_buy_currency_id_fkey FOREIGN KEY (buy_currency_id) REFERENCES public.global_currencies(id);

ALTER TABLE public.product_based_costing_files
  ADD CONSTRAINT product_based_costing_files_customer_group_id_fkey FOREIGN KEY (customer_group_id) REFERENCES public.customer_groups(id) ON DELETE SET NULL;

ALTER TABLE public.product_based_costing_files
  ADD CONSTRAINT product_based_costing_files_default_shipment_id_fkey FOREIGN KEY (default_shipment_id) REFERENCES public.global_shipments(id) ON DELETE SET NULL;

ALTER TABLE public.product_based_costing_files
  ADD CONSTRAINT product_based_costing_files_market_code_fkey FOREIGN KEY (market_code) REFERENCES public.markets(code) ON DELETE SET NULL;

ALTER TABLE public.product_based_costing_files
  ADD CONSTRAINT product_based_costing_files_pkey PRIMARY KEY (id);

ALTER TABLE public.product_based_costing_files
  ADD CONSTRAINT product_based_costing_files_sell_currency_id_fkey FOREIGN KEY (sell_currency_id) REFERENCES public.global_currencies(id);

ALTER TABLE public.product_based_costing_files
  ADD CONSTRAINT product_based_costing_files_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id) ON DELETE SET NULL;

ALTER TABLE public.product_based_costing_files
  ADD CONSTRAINT product_based_costing_files_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

ALTER TABLE public.product_based_costing_files
  ADD CONSTRAINT product_based_costing_files_vendor_id_fkey FOREIGN KEY (vendor_id) REFERENCES public.vendors(id) ON UPDATE CASCADE ON DELETE SET NULL;

GRANT ALL ON public.product_based_costing_files TO anon;

GRANT ALL ON public.product_based_costing_files TO authenticated;

GRANT ALL ON public.product_based_costing_files TO service_role;