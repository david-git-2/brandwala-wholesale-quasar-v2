CREATE TABLE public.thrift_boxes (
  id              bigint                   DEFAULT nextval('public.thrift_boxes_id_seq'::regclass) NOT NULL,
  tenant_id       bigint                   NOT NULL,
  shipment_id     bigint                   NOT NULL,
  name            text                     NOT NULL,
  weight          numeric(12,3),
  received_weight numeric(12,3),
  inserted_by     text                     NOT NULL,
  created_at      timestamp with time zone DEFAULT now() NOT NULL,
  updated_at      timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TRIGGER trg_thrift_boxes_updated_at
  BEFORE UPDATE ON public.thrift_boxes
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY select_thrift_boxes ON public.thrift_boxes
  FOR SELECT
  TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE ((m.tenant_id = thrift_boxes.tenant_id) AND (lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.is_active = true)))));

CREATE POLICY write_thrift_boxes ON public.thrift_boxes
  TO authenticated
  USING (public.membership_has_module_action(tenant_id, 'thrift_box'::text, 'edit'::text));

ALTER SEQUENCE public.thrift_boxes_id_seq OWNED BY public.thrift_boxes.id;

ALTER TABLE public.thrift_boxes
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.thrift_boxes
  ADD CONSTRAINT thrift_boxes_pkey PRIMARY KEY (id);

ALTER TABLE public.thrift_boxes
  ADD CONSTRAINT thrift_boxes_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

ALTER TABLE public.thrift_boxes
  ADD CONSTRAINT thrift_boxes_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.thrift_shipments(id) ON DELETE CASCADE;

GRANT ALL ON public.thrift_boxes TO anon;

GRANT ALL ON public.thrift_boxes TO authenticated;

GRANT ALL ON public.thrift_boxes TO service_role;