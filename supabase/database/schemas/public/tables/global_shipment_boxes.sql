CREATE TABLE public.global_shipment_boxes (
  id               bigint                   DEFAULT nextval('public.global_shipment_boxes_id_seq'::regclass) NOT NULL,
  parent_tenant_id bigint                   NOT NULL,
  shipment_id      bigint                   NOT NULL,
  box_number       text                     NOT NULL,
  created_at       timestamp with time zone DEFAULT now() NOT NULL,
  updated_at       timestamp with time zone DEFAULT now() NOT NULL,
  received_weight  numeric                  NOT NULL,
  shipping_weight  numeric                  NOT NULL
);

CREATE INDEX global_shipment_boxes_parent_tenant_idx ON public.global_shipment_boxes (parent_tenant_id);

CREATE INDEX global_shipment_boxes_shipment_idx ON public.global_shipment_boxes (shipment_id);

CREATE TRIGGER trg_global_shipment_boxes_updated_at
  BEFORE UPDATE ON public.global_shipment_boxes
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY global_shipment_boxes_all ON public.global_shipment_boxes
  TO authenticated
  USING (public.user_can_manage_parent_tenant(parent_tenant_id))
  WITH CHECK (public.user_can_manage_parent_tenant(parent_tenant_id));

CREATE POLICY global_shipment_boxes_select ON public.global_shipment_boxes
  FOR SELECT
  TO authenticated
  USING ((public.user_can_manage_parent_tenant(parent_tenant_id) OR (EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE ((m.tenant_id = global_shipment_boxes.parent_tenant_id) AND (lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.is_active = true))))));

ALTER SEQUENCE public.global_shipment_boxes_id_seq OWNED BY public.global_shipment_boxes.id;

ALTER TABLE public.global_shipment_boxes
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.global_shipment_boxes
  ADD CONSTRAINT global_shipment_boxes_pkey PRIMARY KEY (id);

ALTER TABLE public.global_shipment_boxes
  ADD CONSTRAINT global_shipment_boxes_received_weight_check CHECK (received_weight >= 0::numeric);

ALTER TABLE public.global_shipment_boxes
  ADD CONSTRAINT global_shipment_boxes_shipment_id_box_number_key UNIQUE (shipment_id, box_number);

ALTER TABLE public.global_shipment_boxes
  ADD CONSTRAINT global_shipment_boxes_shipping_weight_check CHECK (shipping_weight >= 0::numeric);

ALTER TABLE public.global_shipment_boxes
  ADD CONSTRAINT global_shipment_boxes_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.global_shipments(id) ON DELETE CASCADE;

ALTER TABLE public.global_shipment_boxes
  ADD CONSTRAINT global_shipment_boxes_parent_tenant_id_fkey FOREIGN KEY (parent_tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.global_shipment_boxes TO anon;

GRANT ALL ON public.global_shipment_boxes TO authenticated;

GRANT ALL ON public.global_shipment_boxes TO service_role;