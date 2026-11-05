CREATE TABLE public.global_shipment_sections (
  id               bigint                   DEFAULT nextval('public.global_shipment_sections_id_seq'::regclass) NOT NULL,
  parent_tenant_id bigint                   NOT NULL,
  shipment_id      bigint                   NOT NULL,
  vendor_id        bigint                   NOT NULL,
  title            text                     NOT NULL,
  sort_order       integer                  DEFAULT 0 NOT NULL,
  metadata         jsonb                    DEFAULT '{}'::jsonb NOT NULL,
  created_at       timestamp with time zone DEFAULT now() NOT NULL,
  updated_at       timestamp with time zone DEFAULT now() NOT NULL
);

CREATE INDEX global_shipment_sections_vendor_idx ON public.global_shipment_sections (vendor_id);

CREATE INDEX global_shipment_sections_parent_tenant_idx ON public.global_shipment_sections (parent_tenant_id);

CREATE INDEX global_shipment_sections_shipment_idx ON public.global_shipment_sections (shipment_id);

CREATE TRIGGER trg_global_shipment_sections_updated_at
  BEFORE UPDATE ON public.global_shipment_sections
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY global_shipment_sections_all ON public.global_shipment_sections
  TO authenticated
  USING (public.user_can_manage_parent_tenant(parent_tenant_id))
  WITH CHECK (public.user_can_manage_parent_tenant(parent_tenant_id));

CREATE POLICY global_shipment_sections_select ON public.global_shipment_sections
  FOR SELECT
  TO authenticated
  USING ((public.user_can_manage_parent_tenant(parent_tenant_id) OR (EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE ((m.tenant_id = global_shipment_sections.parent_tenant_id) AND (lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.is_active = true))))));

ALTER SEQUENCE public.global_shipment_sections_id_seq OWNED BY public.global_shipment_sections.id;

ALTER TABLE public.global_shipment_sections
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.global_shipment_sections
  ADD CONSTRAINT global_shipment_sections_pkey PRIMARY KEY (id);

ALTER TABLE public.global_shipment_sections
  ADD CONSTRAINT global_shipment_sections_title_not_blank CHECK (length(TRIM(BOTH FROM title)) > 0);

ALTER TABLE public.global_shipment_sections
  ADD CONSTRAINT global_shipment_sections_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.global_shipments(id) ON DELETE CASCADE;

ALTER TABLE public.global_shipment_sections
  ADD CONSTRAINT global_shipment_sections_parent_tenant_id_fkey FOREIGN KEY (parent_tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

ALTER TABLE public.global_shipment_sections
  ADD CONSTRAINT global_shipment_sections_vendor_id_fkey FOREIGN KEY (vendor_id) REFERENCES public.vendors(id) ON DELETE RESTRICT;

GRANT ALL ON public.global_shipment_sections TO anon;

GRANT ALL ON public.global_shipment_sections TO authenticated;

GRANT ALL ON public.global_shipment_sections TO service_role;