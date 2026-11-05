CREATE TABLE public.preorder_demand (
  id                 bigint                             GENERATED ALWAYS AS IDENTITY NOT NULL,
  tenant_id          bigint                             NOT NULL,
  source_type        public.preorder_demand_source_type NOT NULL,
  source_id          bigint                             NOT NULL,
  vendor_id          bigint,
  placed_quantity    integer                            DEFAULT 0 NOT NULL,
  delivered_quantity integer                            DEFAULT 0 NOT NULL,
  stock_picks        jsonb                              DEFAULT '[]'::jsonb NOT NULL,
  notes              text,
  updated_by_user_id uuid,
  created_at         timestamp with time zone           DEFAULT now() NOT NULL,
  updated_at         timestamp with time zone           DEFAULT now() NOT NULL,
  profile_id         bigint,
  parent_tenant_id   bigint,
  vendor_placements  jsonb                              DEFAULT '[]'::jsonb NOT NULL,
  confirmed_quantity integer                            DEFAULT 0 NOT NULL,
  open_quantity      integer                            DEFAULT 0 NOT NULL
);

CREATE INDEX preorder_demand_source_idx ON public.preorder_demand (source_type, source_id);

CREATE INDEX preorder_demand_tenant_profile_idx ON public.preorder_demand (tenant_id, profile_id)
  WHERE profile_id IS NOT NULL;

CREATE INDEX preorder_demand_tenant_updated_idx ON public.preorder_demand (tenant_id, updated_at DESC);

CREATE TRIGGER trg_preorder_demand_set_updated_at
  BEFORE UPDATE ON public.preorder_demand
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_preorder_demand_stamp_profile
  BEFORE INSERT OR UPDATE ON public.preorder_demand
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_fn_preorder_demand_stamp_profile();

CREATE POLICY preorder_demand_select ON public.preorder_demand
  FOR SELECT
  TO authenticated
  USING ((public.is_tenant_staff(tenant_id) OR (EXISTS ( SELECT 1
   FROM public.tenants t
  WHERE ((t.id = preorder_demand.tenant_id) AND (t.parent_id IS NOT NULL) AND public.user_can_manage_parent_tenant(t.parent_id))))));

ALTER TABLE public.preorder_demand
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.preorder_demand
  ADD CONSTRAINT preorder_demand_delivered_quantity_check CHECK (delivered_quantity >= 0);

ALTER TABLE public.preorder_demand
  ADD CONSTRAINT preorder_demand_pkey PRIMARY KEY (id);

ALTER TABLE public.preorder_demand
  ADD CONSTRAINT preorder_demand_placed_quantity_check CHECK (placed_quantity >= 0);

ALTER TABLE public.preorder_demand
  ADD CONSTRAINT preorder_demand_source_unique UNIQUE (source_type, source_id);

ALTER TABLE public.preorder_demand
  ADD CONSTRAINT preorder_demand_stock_picks_is_array CHECK (jsonb_typeof(stock_picks) = 'array'::text);

ALTER TABLE public.preorder_demand
  ADD CONSTRAINT preorder_demand_updated_by_user_id_fkey FOREIGN KEY (updated_by_user_id) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.preorder_demand
  ADD CONSTRAINT preorder_demand_vendor_placements_is_array CHECK (jsonb_typeof(vendor_placements) = 'array'::text);

ALTER TABLE public.preorder_demand
  ADD CONSTRAINT preorder_demand_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id) ON DELETE SET NULL;

ALTER TABLE public.preorder_demand
  ADD CONSTRAINT preorder_demand_parent_tenant_id_fkey FOREIGN KEY (parent_tenant_id) REFERENCES public.tenants(id);

ALTER TABLE public.preorder_demand
  ADD CONSTRAINT preorder_demand_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

ALTER TABLE public.preorder_demand
  ADD CONSTRAINT preorder_demand_vendor_id_fkey FOREIGN KEY (vendor_id) REFERENCES public.vendors(id) ON DELETE SET NULL;

GRANT ALL ON public.preorder_demand TO anon;

GRANT ALL ON public.preorder_demand TO authenticated;

GRANT ALL ON public.preorder_demand TO service_role;