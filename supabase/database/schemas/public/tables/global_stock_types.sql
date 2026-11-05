CREATE TABLE public.global_stock_types (
  id               bigint                   DEFAULT nextval('public.global_stock_types_id_seq'::regclass) NOT NULL,
  parent_tenant_id bigint,
  description      text                     NOT NULL,
  is_sellable      boolean                  DEFAULT true NOT NULL,
  sort_order       integer                  DEFAULT 0 NOT NULL,
  created_at       timestamp with time zone DEFAULT now() NOT NULL,
  updated_at       timestamp with time zone DEFAULT now() NOT NULL
);

CREATE INDEX global_stock_types_parent_tenant_idx ON public.global_stock_types (parent_tenant_id);

CREATE TRIGGER trg_global_stock_types_updated_at
  BEFORE UPDATE ON public.global_stock_types
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY global_stock_types_all ON public.global_stock_types
  TO authenticated
  USING ((public.is_superadmin() OR (parent_tenant_id IS NULL) OR public.user_can_manage_parent_tenant(parent_tenant_id)))
  WITH CHECK ((public.is_superadmin() OR (parent_tenant_id IS NULL) OR public.user_can_manage_parent_tenant(parent_tenant_id)));

CREATE POLICY global_stock_types_select ON public.global_stock_types
  FOR SELECT
  TO authenticated
  USING (true);

ALTER SEQUENCE public.global_stock_types_id_seq OWNED BY public.global_stock_types.id;

ALTER TABLE public.global_stock_types
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.global_stock_types
  ADD CONSTRAINT global_stock_types_desc_not_blank CHECK (length(TRIM(BOTH FROM description)) > 0);

ALTER TABLE public.global_stock_types
  ADD CONSTRAINT global_stock_types_pkey PRIMARY KEY (id);

ALTER TABLE public.global_stock_types
  ADD CONSTRAINT global_stock_types_parent_tenant_id_fkey FOREIGN KEY (parent_tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.global_stock_types TO anon;

GRANT ALL ON public.global_stock_types TO authenticated;

GRANT ALL ON public.global_stock_types TO service_role;