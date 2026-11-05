CREATE TABLE public.costing_file_items (
  id                       bigint                          DEFAULT nextval('public.costing_file_items_id_seq'::regclass) NOT NULL,
  costing_file_id          bigint                          NOT NULL,
  name                     text,
  image_url                text,
  website_url              text                            NOT NULL,
  quantity                 integer                         NOT NULL,
  product_weight           integer,
  package_weight           integer,
  price_in_web_gbp         numeric(12,2),
  delivery_price_gbp       numeric(12,2),
  auxiliary_price_gbp      numeric(12,2),
  item_price_gbp           numeric(12,2),
  cargo_rate               numeric(12,2),
  costing_price_gbp        numeric(12,2),
  costing_price_bdt        integer,
  offer_price_bdt          integer,
  customer_profit_rate     numeric(12,2),
  status                   public.costing_file_item_status DEFAULT 'pending'::public.costing_file_item_status NOT NULL,
  created_by_email         text                            DEFAULT public.current_user_email() NOT NULL,
  created_at               timestamp with time zone        DEFAULT now() NOT NULL,
  updated_at               timestamp with time zone        DEFAULT now() NOT NULL,
  offer_price_override_bdt integer,
  size                     text,
  color                    text,
  extra_information_1      text,
  extra_information_2      text,
  item_type                text,
  cargo_rate_is_manual     boolean                         DEFAULT false NOT NULL,
  assigned_shipment_id     bigint
);

CREATE INDEX costing_file_items_status_idx ON public.costing_file_items (status);

CREATE INDEX costing_file_items_costing_file_id_idx ON public.costing_file_items (costing_file_id);

CREATE TRIGGER trg_costing_file_items_apply_calculations
  BEFORE INSERT OR UPDATE ON public.costing_file_items
  FOR EACH ROW
  EXECUTE FUNCTION public.apply_costing_item_calculations();

CREATE TRIGGER trg_costing_file_items_enforce_update_rules
  BEFORE UPDATE ON public.costing_file_items
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_costing_file_item_update_rules();

CREATE TRIGGER trg_costing_file_items_normalize_fields
  BEFORE INSERT OR UPDATE ON public.costing_file_items
  FOR EACH ROW
  EXECUTE FUNCTION public.normalize_costing_file_item_fields();

CREATE TRIGGER trg_costing_file_items_updated_at
  BEFORE UPDATE ON public.costing_file_items
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY costing_file_items_select ON public.costing_file_items
  FOR SELECT
  TO authenticated
  USING (public.can_view_costing_file_items(costing_file_id));

CREATE POLICY costing_file_items_delete ON public.costing_file_items
  FOR DELETE
  TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM public.costing_files cf
  WHERE
    ((cf.id = costing_file_items.costing_file_id) AND (public.can_admin_manage_costing_file(cf.tenant_id) OR public.can_staff_access_costing_file(cf.tenant_id) OR ((cf.status =
    'draft'::public.costing_file_status) AND public.can_customer_access_costing_file(cf.customer_group_id)))))));

CREATE POLICY costing_file_items_insert ON public.costing_file_items
  FOR INSERT
  TO authenticated
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.costing_files cf
  WHERE
    ((cf.id = costing_file_items.costing_file_id) AND (public.can_admin_manage_costing_file(cf.tenant_id) OR public.can_staff_access_costing_file(cf.tenant_id) OR ((cf.status =
    'draft'::public.costing_file_status) AND public.can_customer_access_costing_file(cf.customer_group_id)))))));

CREATE POLICY costing_file_items_update ON public.costing_file_items
  FOR UPDATE
  TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM public.costing_files cf
  WHERE
    ((cf.id = costing_file_items.costing_file_id) AND (public.can_admin_manage_costing_file(cf.tenant_id) OR public.can_staff_access_costing_file(cf.tenant_id) OR
    public.can_customer_access_costing_file(cf.customer_group_id))))))
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.costing_files cf
  WHERE
    ((cf.id = costing_file_items.costing_file_id) AND (public.can_admin_manage_costing_file(cf.tenant_id) OR public.can_staff_access_costing_file(cf.tenant_id) OR
    public.can_customer_access_costing_file(cf.customer_group_id))))));

ALTER SEQUENCE public.costing_file_items_id_seq OWNED BY public.costing_file_items.id;

ALTER TABLE public.costing_file_items
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.costing_file_items
  ADD CONSTRAINT costing_file_items_auxiliary_price_gbp_nonnegative CHECK (auxiliary_price_gbp IS NULL OR auxiliary_price_gbp >= 0::numeric);

ALTER TABLE public.costing_file_items
  ADD CONSTRAINT costing_file_items_cargo_rate_nonnegative CHECK (cargo_rate IS NULL OR cargo_rate >= 0::numeric);

ALTER TABLE public.costing_file_items
  ADD CONSTRAINT costing_file_items_costing_price_bdt_nonnegative CHECK (costing_price_bdt IS NULL OR costing_price_bdt >= 0);

ALTER TABLE public.costing_file_items
  ADD CONSTRAINT costing_file_items_costing_price_gbp_nonnegative CHECK (costing_price_gbp IS NULL OR costing_price_gbp >= 0::numeric);

ALTER TABLE public.costing_file_items
  ADD CONSTRAINT costing_file_items_customer_profit_rate_nonnegative CHECK (customer_profit_rate IS NULL OR customer_profit_rate >= 0::numeric);

ALTER TABLE public.costing_file_items
  ADD CONSTRAINT costing_file_items_delivery_price_gbp_nonnegative CHECK (delivery_price_gbp IS NULL OR delivery_price_gbp >= 0::numeric);

ALTER TABLE public.costing_file_items
  ADD CONSTRAINT costing_file_items_item_price_gbp_nonnegative CHECK (item_price_gbp IS NULL OR item_price_gbp >= 0::numeric);

ALTER TABLE public.costing_file_items
  ADD CONSTRAINT costing_file_items_item_type_not_blank CHECK (item_type IS NULL OR length(TRIM(BOTH FROM item_type)) > 0);

ALTER TABLE public.costing_file_items
  ADD CONSTRAINT costing_file_items_offer_price_bdt_nonnegative CHECK (offer_price_bdt IS NULL OR offer_price_bdt >= 0);

ALTER TABLE public.costing_file_items
  ADD CONSTRAINT costing_file_items_offer_price_override_bdt_nonnegative CHECK (offer_price_override_bdt IS NULL OR offer_price_override_bdt >= 0);

ALTER TABLE public.costing_file_items
  ADD CONSTRAINT costing_file_items_package_weight_nonnegative CHECK (package_weight IS NULL OR package_weight >= 0);

ALTER TABLE public.costing_file_items
  ADD CONSTRAINT costing_file_items_pkey PRIMARY KEY (id);

ALTER TABLE public.costing_file_items
  ADD CONSTRAINT costing_file_items_price_in_web_gbp_nonnegative CHECK (price_in_web_gbp IS NULL OR price_in_web_gbp >= 0::numeric);

ALTER TABLE public.costing_file_items
  ADD CONSTRAINT costing_file_items_product_weight_nonnegative CHECK (product_weight IS NULL OR product_weight >= 0);

ALTER TABLE public.costing_file_items
  ADD CONSTRAINT costing_file_items_quantity_positive CHECK (quantity > 0);

ALTER TABLE public.costing_file_items
  ADD CONSTRAINT costing_file_items_website_url_not_blank CHECK (length(TRIM(BOTH FROM website_url)) > 0);

ALTER TABLE public.costing_file_items
  ADD CONSTRAINT costing_file_items_costing_file_id_fkey FOREIGN KEY (costing_file_id) REFERENCES public.costing_files(id) ON DELETE CASCADE;

ALTER TABLE public.costing_file_items
  ADD CONSTRAINT costing_file_items_assigned_shipment_id_fkey FOREIGN KEY (assigned_shipment_id) REFERENCES public.shipments(id) ON DELETE SET NULL;

GRANT ALL ON public.costing_file_items TO anon;

GRANT ALL ON public.costing_file_items TO authenticated;

GRANT ALL ON public.costing_file_items TO service_role;