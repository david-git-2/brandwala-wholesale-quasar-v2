CREATE TABLE public.shipment_progress_flow_stages (
  id         bigint                   DEFAULT nextval('public.shipment_progress_flow_stages_id_seq'::regclass) NOT NULL,
  flow_id    bigint                   NOT NULL,
  tag_id     bigint                   NOT NULL,
  sort_order integer                  DEFAULT 1 NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE UNIQUE INDEX shipment_progress_flow_stages_flow_tag_key ON public.shipment_progress_flow_stages (flow_id, tag_id);

CREATE UNIQUE INDEX shipment_progress_flow_stages_flow_sort_key ON public.shipment_progress_flow_stages (flow_id, sort_order);

CREATE POLICY shipment_progress_flow_stages_all ON public.shipment_progress_flow_stages
  TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM public.shipment_progress_flows f
  WHERE ((f.id = shipment_progress_flow_stages.flow_id) AND public.user_can_manage_parent_tenant(f.tenant_id)))))
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.shipment_progress_flows f
  WHERE ((f.id = shipment_progress_flow_stages.flow_id) AND public.user_can_manage_parent_tenant(f.tenant_id)))));

ALTER SEQUENCE public.shipment_progress_flow_stages_id_seq OWNED BY public.shipment_progress_flow_stages.id;

ALTER TABLE public.shipment_progress_flow_stages
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.shipment_progress_flow_stages
  ADD CONSTRAINT shipment_progress_flow_stages_pkey PRIMARY KEY (id);

ALTER TABLE public.shipment_progress_flow_stages
  ADD CONSTRAINT shipment_progress_flow_stages_flow_id_fkey FOREIGN KEY (flow_id) REFERENCES public.shipment_progress_flows(id) ON DELETE CASCADE;

ALTER TABLE public.shipment_progress_flow_stages
  ADD CONSTRAINT shipment_progress_flow_stages_tag_id_fkey FOREIGN KEY (tag_id) REFERENCES public.tags(id) ON DELETE RESTRICT;

GRANT ALL ON public.shipment_progress_flow_stages TO anon;

GRANT ALL ON public.shipment_progress_flow_stages TO authenticated;

GRANT ALL ON public.shipment_progress_flow_stages TO service_role;