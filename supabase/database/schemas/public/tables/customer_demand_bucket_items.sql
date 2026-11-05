CREATE TABLE public.customer_demand_bucket_items (
  id               bigint                           GENERATED ALWAYS AS IDENTITY NOT NULL,
  tenant_id        bigint                           NOT NULL,
  profile_id       bigint                           NOT NULL,
  product_id       bigint                           NOT NULL,
  source_type      public.demand_bucket_source_type NOT NULL,
  source_id        bigint,
  name             text                             NOT NULL,
  image_url        text,
  barcode          text,
  product_code     text,
  note             text,
  quantity         integer                          DEFAULT 1 NOT NULL,
  status           public.demand_bucket_status      DEFAULT 'open'::public.demand_bucket_status NOT NULL,
  popped_at        timestamp with time zone,
  popped_into_type text,
  popped_into_id   bigint,
  created_at       timestamp with time zone         DEFAULT now() NOT NULL,
  updated_at       timestamp with time zone         DEFAULT now() NOT NULL
);

CREATE INDEX idx_demand_bucket_source ON public.customer_demand_bucket_items (source_type, source_id)
  WHERE source_id IS NOT NULL;

CREATE INDEX idx_demand_bucket_popped_purge ON public.customer_demand_bucket_items (popped_at)
  WHERE status = 'popped'::public.demand_bucket_status;

CREATE INDEX idx_demand_bucket_open_profile ON public.customer_demand_bucket_items (tenant_id, profile_id)
  WHERE status = 'open'::public.demand_bucket_status;

CREATE TRIGGER trg_customer_demand_bucket_items_set_updated_at
  BEFORE UPDATE ON public.customer_demand_bucket_items
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY customer_demand_bucket_items_tenant_isolation ON public.customer_demand_bucket_items
  USING ((tenant_id = (NULLIF(current_setting('app.current_tenant_id'::text, true), ''::text))::bigint));

ALTER TABLE public.customer_demand_bucket_items
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.customer_demand_bucket_items
  ADD CONSTRAINT customer_demand_bucket_items_pkey PRIMARY KEY (id);

ALTER TABLE public.customer_demand_bucket_items
  ADD CONSTRAINT customer_demand_bucket_items_quantity_check CHECK (quantity > 0);

ALTER TABLE public.customer_demand_bucket_items
  ADD CONSTRAINT customer_demand_bucket_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE CASCADE;

ALTER TABLE public.customer_demand_bucket_items
  ADD CONSTRAINT customer_demand_bucket_items_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

ALTER TABLE public.customer_demand_bucket_items
  ADD CONSTRAINT customer_demand_bucket_items_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.customer_demand_bucket_items TO anon;

GRANT ALL ON public.customer_demand_bucket_items TO authenticated;

GRANT ALL ON public.customer_demand_bucket_items TO service_role;