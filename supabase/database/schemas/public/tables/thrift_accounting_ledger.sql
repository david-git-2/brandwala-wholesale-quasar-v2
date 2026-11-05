CREATE TABLE public.thrift_accounting_ledger (
  id           bigint                      DEFAULT nextval('public.thrift_accounting_ledger_id_seq'::regclass) NOT NULL,
  tenant_id    bigint                      NOT NULL,
  type         public.thrift_ledger_type   NOT NULL,
  source       public.thrift_ledger_source NOT NULL,
  reference_id bigint                      NOT NULL,
  amount       numeric(12,2)               NOT NULL,
  date         timestamp with time zone    DEFAULT now() NOT NULL,
  inserted_by  text                        NOT NULL,
  note         text,
  created_at   timestamp with time zone    DEFAULT now() NOT NULL,
  updated_at   timestamp with time zone    DEFAULT now() NOT NULL
);

CREATE TRIGGER trg_thrift_accounting_ledger_updated_at
  BEFORE UPDATE ON public.thrift_accounting_ledger
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY select_thrift_ledger ON public.thrift_accounting_ledger
  FOR SELECT
  TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE ((m.tenant_id = thrift_accounting_ledger.tenant_id) AND (lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.is_active = true)))));

CREATE POLICY write_thrift_ledger ON public.thrift_accounting_ledger
  TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE
    ((m.tenant_id = thrift_accounting_ledger.tenant_id) AND (lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.is_active = true) AND (m.role = ANY
    (ARRAY['admin'::public.app_role, 'staff'::public.app_role]))))));

ALTER SEQUENCE public.thrift_accounting_ledger_id_seq OWNED BY public.thrift_accounting_ledger.id;

ALTER TABLE public.thrift_accounting_ledger
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.thrift_accounting_ledger
  ADD CONSTRAINT thrift_accounting_ledger_amount_check CHECK (amount >= 0::numeric);

ALTER TABLE public.thrift_accounting_ledger
  ADD CONSTRAINT thrift_accounting_ledger_pkey PRIMARY KEY (id);

ALTER TABLE public.thrift_accounting_ledger
  ADD CONSTRAINT thrift_accounting_ledger_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.thrift_accounting_ledger TO anon;

GRANT ALL ON public.thrift_accounting_ledger TO authenticated;

GRANT ALL ON public.thrift_accounting_ledger TO service_role;