CREATE TABLE public.product_based_costing_backlog_items (
  id                   bigint                   GENERATED ALWAYS AS IDENTITY NOT NULL,
  tenant_id            bigint                   NOT NULL,
  profile_id           bigint                   NOT NULL,
  product_id           bigint                   NOT NULL,
  open_quantity        integer                  NOT NULL,
  name                 text                     NOT NULL,
  image_url            text,
  barcode              text,
  product_code         text,
  price_gbp            numeric,
  product_weight       numeric,
  package_weight       numeric,
  note                 text,
  last_costing_file_id bigint,
  last_costing_item_id bigint,
  created_at           timestamp with time zone DEFAULT now() NOT NULL,
  updated_at           timestamp with time zone DEFAULT now() NOT NULL
);

CREATE INDEX idx_pbc_backlog_tenant_profile ON public.product_based_costing_backlog_items (tenant_id, profile_id);

CREATE POLICY "Tenant members can delete product_based_costing_backlog_items" ON public.product_based_costing_backlog_items
  FOR DELETE
  TO authenticated
  USING ((public.can_admin_manage_costing_file(tenant_id) OR public.can_staff_access_costing_file(tenant_id)));

CREATE POLICY "Tenant members can insert product_based_costing_backlog_items" ON public.product_based_costing_backlog_items
  FOR INSERT
  TO authenticated
  WITH CHECK ((public.can_admin_manage_costing_file(tenant_id) OR public.can_staff_access_costing_file(tenant_id)));

CREATE POLICY "Tenant members can select product_based_costing_backlog_items" ON public.product_based_costing_backlog_items
  FOR SELECT
  TO authenticated
  USING ((public.can_admin_manage_costing_file(tenant_id) OR public.can_staff_access_costing_file(tenant_id)));

CREATE POLICY "Tenant members can update product_based_costing_backlog_items" ON public.product_based_costing_backlog_items
  FOR UPDATE
  TO authenticated
  USING ((public.can_admin_manage_costing_file(tenant_id) OR public.can_staff_access_costing_file(tenant_id)));

ALTER TABLE public.product_based_costing_backlog_items
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.product_based_costing_backlog_items
  ADD CONSTRAINT product_based_costing_backlog_items_open_quantity_check CHECK (open_quantity > 0);

ALTER TABLE public.product_based_costing_backlog_items
  ADD CONSTRAINT product_based_costing_backlog_items_pkey PRIMARY KEY (id);

ALTER TABLE public.product_based_costing_backlog_items
  ADD CONSTRAINT uq_pbc_backlog_tenant_profile_product UNIQUE (tenant_id, profile_id, product_id);

ALTER TABLE public.product_based_costing_backlog_items
  ADD CONSTRAINT product_based_costing_backlog_items_last_costing_file_id_fkey FOREIGN KEY (last_costing_file_id) REFERENCES public.product_based_costing_files(id) ON DELETE
    SET NULL;

ALTER TABLE public.product_based_costing_backlog_items
  ADD CONSTRAINT product_based_costing_backlog_items_last_costing_item_id_fkey FOREIGN KEY (last_costing_item_id) REFERENCES public.product_based_costing_items(id) ON DELETE
    SET NULL;

ALTER TABLE public.product_based_costing_backlog_items
  ADD CONSTRAINT product_based_costing_backlog_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE CASCADE;

ALTER TABLE public.product_based_costing_backlog_items
  ADD CONSTRAINT product_based_costing_backlog_items_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

ALTER TABLE public.product_based_costing_backlog_items
  ADD CONSTRAINT product_based_costing_backlog_items_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.product_based_costing_backlog_items TO anon;

GRANT ALL ON public.product_based_costing_backlog_items TO authenticated;

GRANT ALL ON public.product_based_costing_backlog_items TO service_role;