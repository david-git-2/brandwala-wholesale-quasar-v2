CREATE TABLE public.costing_files (
  id                  bigint                     DEFAULT nextval('public.costing_files_id_seq'::regclass) NOT NULL,
  name                text                       NOT NULL,
  cargo_rate_1kg      numeric(12,2),
  cargo_rate_2kg      numeric(12,2),
  conversion_rate     numeric(12,2),
  admin_profit_rate   numeric(12,2),
  status              public.costing_file_status DEFAULT 'draft'::public.costing_file_status NOT NULL,
  market              text,
  customer_group_id   bigint                     NOT NULL,
  tenant_id           bigint                     NOT NULL,
  created_by_email    text                       DEFAULT public.current_user_email() NOT NULL,
  created_at          timestamp with time zone   DEFAULT now() NOT NULL,
  updated_at          timestamp with time zone   DEFAULT now() NOT NULL,
  default_shipment_id bigint
);

CREATE INDEX costing_files_status_idx ON public.costing_files (status);

CREATE INDEX costing_files_tenant_id_idx ON public.costing_files (tenant_id);

CREATE INDEX costing_files_customer_group_id_idx ON public.costing_files (customer_group_id);

CREATE TRIGGER trg_costing_files_normalize_market
  BEFORE INSERT OR UPDATE ON public.costing_files
  FOR EACH ROW
  EXECUTE FUNCTION public.normalize_costing_file_market();

CREATE TRIGGER trg_costing_files_normalize_status_po_placed
  BEFORE INSERT OR UPDATE ON public.costing_files
  FOR EACH ROW
  EXECUTE FUNCTION public.normalize_costing_file_status_po_placed();

CREATE TRIGGER trg_costing_files_refresh_item_calculations
  AFTER UPDATE ON public.costing_files
  FOR EACH ROW
  EXECUTE FUNCTION public.refresh_costing_file_item_calculations_for_file();

CREATE TRIGGER trg_costing_files_updated_at
  BEFORE UPDATE ON public.costing_files
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_costing_files_validate_customer_group
  BEFORE INSERT OR UPDATE ON public.costing_files
  FOR EACH ROW
  EXECUTE FUNCTION public.validate_costing_file_customer_group();

CREATE POLICY costing_files_delete ON public.costing_files
  FOR DELETE
  TO authenticated
  USING ((public.can_admin_manage_costing_file(tenant_id) OR ((status = 'draft'::public.costing_file_status) AND public.can_customer_access_costing_file(customer_group_id))));

CREATE POLICY costing_files_insert ON public.costing_files
  FOR INSERT
  TO authenticated
  WITH CHECK ((public.can_admin_manage_costing_file(tenant_id) OR public.can_staff_access_costing_file(tenant_id) OR public.can_customer_access_costing_file(customer_group_id)));

CREATE POLICY costing_files_select ON public.costing_files
  FOR SELECT
  TO authenticated
  USING (public.can_view_costing_file(id));

CREATE POLICY costing_files_update ON public.costing_files
  FOR UPDATE
  TO authenticated
  USING ((public.can_admin_manage_costing_file(tenant_id) OR public.can_staff_access_costing_file(tenant_id)))
  WITH CHECK ((public.can_admin_manage_costing_file(tenant_id) OR public.can_staff_access_costing_file(tenant_id)));

ALTER SEQUENCE public.costing_files_id_seq OWNED BY public.costing_files.id;

ALTER TABLE public.costing_files
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.costing_files
  ADD CONSTRAINT costing_files_admin_profit_rate_nonnegative CHECK (admin_profit_rate IS NULL OR admin_profit_rate >= 0::numeric);

ALTER TABLE public.costing_files
  ADD CONSTRAINT costing_files_cargo_rate_1kg_nonnegative CHECK (cargo_rate_1kg IS NULL OR cargo_rate_1kg >= 0::numeric);

ALTER TABLE public.costing_files
  ADD CONSTRAINT costing_files_cargo_rate_2kg_nonnegative CHECK (cargo_rate_2kg IS NULL OR cargo_rate_2kg >= 0::numeric);

ALTER TABLE public.costing_files
  ADD CONSTRAINT costing_files_conversion_rate_nonnegative CHECK (conversion_rate IS NULL OR conversion_rate >= 0::numeric);

ALTER TABLE public.costing_files
  ADD CONSTRAINT costing_files_name_not_blank CHECK (length(TRIM(BOTH FROM name)) > 0);

ALTER TABLE public.costing_files
  ADD CONSTRAINT costing_files_pkey PRIMARY KEY (id);

ALTER TABLE public.costing_files
  ADD CONSTRAINT costing_files_customer_group_id_fkey FOREIGN KEY (customer_group_id) REFERENCES public.customer_groups(id) ON DELETE CASCADE;

ALTER TABLE public.costing_files
  ADD CONSTRAINT costing_files_default_shipment_id_fkey FOREIGN KEY (default_shipment_id) REFERENCES public.shipments(id) ON DELETE SET NULL;

ALTER TABLE public.costing_files
  ADD CONSTRAINT costing_files_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.costing_files TO anon;

GRANT ALL ON public.costing_files TO authenticated;

GRANT ALL ON public.costing_files TO service_role;