CREATE TABLE public.pickup_locations (
  id              uuid                     DEFAULT gen_random_uuid() NOT NULL,
  tenant_id       bigint                   NOT NULL,
  location_name   text                     NOT NULL,
  store_name      text,
  phone_primary   text                     NOT NULL,
  phone_secondary text,
  pickup_address  text                     NOT NULL,
  district        text                     DEFAULT 'Dhaka'::text NOT NULL,
  thana           text                     NOT NULL,
  notes           text,
  is_active       boolean                  DEFAULT true NOT NULL,
  created_at      timestamp with time zone DEFAULT now() NOT NULL,
  updated_at      timestamp with time zone DEFAULT now() NOT NULL
);

CREATE INDEX idx_pickup_locations_tenant ON public.pickup_locations (tenant_id);

CREATE POLICY "Authenticated users can select tenant pickup locations" ON public.pickup_locations
  FOR SELECT
  TO authenticated
  USING (((tenant_id = ( SELECT (current_setting('app.current_tenant_id'::text, true))::bigint AS current_setting)) OR (EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE ((lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.tenant_id = pickup_locations.tenant_id) AND (m.is_active = true))))));

CREATE POLICY "Members can delete pickup locations" ON public.pickup_locations
  FOR DELETE
  TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE ((lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.tenant_id = pickup_locations.tenant_id) AND (m.is_active = true)))));

CREATE POLICY "Members can insert pickup locations" ON public.pickup_locations
  FOR INSERT
  TO authenticated
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE ((lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.tenant_id = pickup_locations.tenant_id) AND (m.is_active = true)))));

CREATE POLICY "Members can update pickup locations" ON public.pickup_locations
  FOR UPDATE
  TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE ((lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.tenant_id = pickup_locations.tenant_id) AND (m.is_active = true)))))
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE ((lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.tenant_id = pickup_locations.tenant_id) AND (m.is_active = true)))));

ALTER TABLE public.pickup_locations
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.pickup_locations
  ADD CONSTRAINT pickup_locations_pkey PRIMARY KEY (id);

ALTER TABLE public.pickup_locations
  ADD CONSTRAINT pickup_locations_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.pickup_locations TO anon;

GRANT ALL ON public.pickup_locations TO authenticated;

GRANT ALL ON public.pickup_locations TO service_role;