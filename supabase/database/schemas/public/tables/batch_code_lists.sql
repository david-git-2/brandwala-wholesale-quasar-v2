CREATE TABLE public.batch_code_lists (
  id               bigint                   DEFAULT nextval('public.batch_code_lists_id_seq'::regclass) NOT NULL,
  parent_tenant_id bigint                   NOT NULL,
  shipment_id      bigint                   NOT NULL,
  created_at       timestamp with time zone DEFAULT now() NOT NULL,
  updated_at       timestamp with time zone DEFAULT now() NOT NULL
);

CREATE UNIQUE INDEX batch_code_lists_shipment_id_key ON public.batch_code_lists (shipment_id);

CREATE INDEX batch_code_lists_parent_tenant_idx ON public.batch_code_lists (parent_tenant_id);

CREATE TRIGGER trg_batch_code_lists_updated_at
  BEFORE UPDATE ON public.batch_code_lists
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY batch_code_lists_all ON public.batch_code_lists
  TO authenticated
  USING (public.user_can_manage_parent_tenant(parent_tenant_id))
  WITH CHECK (public.user_can_manage_parent_tenant(parent_tenant_id));

CREATE POLICY batch_code_lists_select ON public.batch_code_lists
  FOR SELECT
  TO authenticated
  USING ((public.user_can_manage_parent_tenant(parent_tenant_id) OR (EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE ((m.tenant_id = batch_code_lists.parent_tenant_id) AND (lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.is_active = true))))));

ALTER SEQUENCE public.batch_code_lists_id_seq OWNED BY public.batch_code_lists.id;

ALTER TABLE public.batch_code_lists
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.batch_code_lists
  ADD CONSTRAINT batch_code_lists_pkey PRIMARY KEY (id);

ALTER TABLE public.batch_code_lists
  ADD CONSTRAINT batch_code_lists_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.global_shipments(id) ON DELETE CASCADE;

ALTER TABLE public.batch_code_lists
  ADD CONSTRAINT batch_code_lists_parent_tenant_id_fkey FOREIGN KEY (parent_tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.batch_code_lists TO anon;

GRANT ALL ON public.batch_code_lists TO authenticated;

GRANT ALL ON public.batch_code_lists TO service_role;