CREATE TABLE public.shipment_progress_flows (
  id         bigint                   DEFAULT nextval('public.shipment_progress_flows_id_seq'::regclass) NOT NULL,
  tenant_id  bigint                   NOT NULL,
  name       text                     NOT NULL,
  slug       text                     NOT NULL,
  is_active  boolean                  DEFAULT true NOT NULL,
  is_default boolean                  DEFAULT false NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE UNIQUE INDEX shipment_progress_flows_tenant_slug_key ON public.shipment_progress_flows (tenant_id, slug);

CREATE UNIQUE INDEX shipment_progress_flows_one_default_per_tenant ON public.shipment_progress_flows (tenant_id)
  WHERE is_default = true;

CREATE POLICY shipment_progress_flows_all ON public.shipment_progress_flows
  TO authenticated
  USING (public.user_can_manage_parent_tenant(tenant_id))
  WITH CHECK (public.user_can_manage_parent_tenant(tenant_id));

ALTER SEQUENCE public.shipment_progress_flows_id_seq OWNED BY public.shipment_progress_flows.id;

ALTER TABLE public.shipment_progress_flows
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.shipment_progress_flows
  ADD CONSTRAINT shipment_progress_flows_pkey PRIMARY KEY (id);

ALTER TABLE public.shipment_progress_flows
  ADD CONSTRAINT shipment_progress_flows_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.shipment_progress_flows TO anon;

GRANT ALL ON public.shipment_progress_flows TO authenticated;

GRANT ALL ON public.shipment_progress_flows TO service_role;