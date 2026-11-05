CREATE TABLE public.thrift_shelves (
  id           bigint                   DEFAULT nextval('public.thrift_shelves_id_seq'::regclass) NOT NULL,
  tenant_id    bigint                   NOT NULL,
  name         text                     NOT NULL,
  location_bay text,
  shelf_code   text                     NOT NULL,
  inserted_by  text                     NOT NULL,
  created_at   timestamp with time zone DEFAULT now() NOT NULL,
  updated_at   timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TRIGGER trg_thrift_shelves_updated_at
  BEFORE UPDATE ON public.thrift_shelves
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY select_thrift_shelves ON public.thrift_shelves
  FOR SELECT
  TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE ((m.tenant_id = thrift_shelves.tenant_id) AND (lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.is_active = true)))));

CREATE POLICY write_thrift_shelves ON public.thrift_shelves
  TO authenticated
  USING (public.membership_has_module_action(tenant_id, 'thrift_shelf'::text, 'edit'::text));

ALTER SEQUENCE public.thrift_shelves_id_seq OWNED BY public.thrift_shelves.id;

ALTER TABLE public.thrift_shelves
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.thrift_shelves
  ADD CONSTRAINT thrift_shelves_code_tenant_unique UNIQUE (tenant_id, shelf_code);

ALTER TABLE public.thrift_shelves
  ADD CONSTRAINT thrift_shelves_pkey PRIMARY KEY (id);

ALTER TABLE public.thrift_shelves
  ADD CONSTRAINT thrift_shelves_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.thrift_shelves TO anon;

GRANT ALL ON public.thrift_shelves TO authenticated;

GRANT ALL ON public.thrift_shelves TO service_role;