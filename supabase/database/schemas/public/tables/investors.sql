CREATE TABLE public.investors (
  id            bigint                   DEFAULT nextval('public.investors_id_seq'::regclass) NOT NULL,
  tenant_id     bigint                   NOT NULL,
  name          text                     NOT NULL,
  phone         text,
  email         text,
  address       text,
  created_at    timestamp with time zone DEFAULT now() NOT NULL,
  updated_at    timestamp with time zone DEFAULT now() NOT NULL,
  is_active     boolean                  DEFAULT true NOT NULL,
  currency_code text                     DEFAULT 'BDT'::text NOT NULL,
  notes         text
);

CREATE INDEX investors_tenant_id_idx ON public.investors (tenant_id);

CREATE TRIGGER trg_investors_set_updated_at
  BEFORE UPDATE ON public.investors
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY investors_select ON public.investors
  FOR SELECT
  TO authenticated
  USING ((public.investor_tenant_can_view(tenant_id) OR (public.auth_investor_id() = id)));

CREATE POLICY investors_delete ON public.investors
  FOR DELETE
  TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE
    ((m.tenant_id = investors.tenant_id) AND (lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.is_active = true) AND (m.role = ANY
    (ARRAY['admin'::public.app_role, 'staff'::public.app_role]))))));

CREATE POLICY investors_insert ON public.investors
  FOR INSERT
  TO authenticated
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE
    ((m.tenant_id = investors.tenant_id) AND (lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.is_active = true) AND (m.role = ANY
    (ARRAY['admin'::public.app_role, 'staff'::public.app_role]))))));

CREATE POLICY investors_update ON public.investors
  FOR UPDATE
  TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE
    ((m.tenant_id = investors.tenant_id) AND (lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.is_active = true) AND (m.role = ANY
    (ARRAY['admin'::public.app_role, 'staff'::public.app_role]))))))
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE
    ((m.tenant_id = investors.tenant_id) AND (lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.is_active = true) AND (m.role = ANY
    (ARRAY['admin'::public.app_role, 'staff'::public.app_role]))))));

ALTER SEQUENCE public.investors_id_seq OWNED BY public.investors.id;

ALTER TABLE public.investors
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.investors
  ADD CONSTRAINT investors_pkey PRIMARY KEY (id);

ALTER TABLE public.investors
  ADD CONSTRAINT investors_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.investors TO anon;

GRANT ALL ON public.investors TO authenticated;

GRANT ALL ON public.investors TO service_role;