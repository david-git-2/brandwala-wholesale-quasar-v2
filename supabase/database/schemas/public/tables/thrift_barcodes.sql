CREATE TABLE public.thrift_barcodes (
  id          bigint                   DEFAULT nextval('public.thrift_barcodes_id_seq'::regclass) NOT NULL,
  tenant_id   bigint                   NOT NULL,
  barcode_id  text                     NOT NULL,
  status      text                     DEFAULT 'AVAILABLE'::text NOT NULL,
  is_printed  smallint                 DEFAULT 0 NOT NULL,
  inserted_by text                     NOT NULL,
  created_at  timestamp with time zone DEFAULT now() NOT NULL,
  updated_at  timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TRIGGER trg_thrift_barcodes_updated_at
  BEFORE UPDATE ON public.thrift_barcodes
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY select_thrift_barcodes ON public.thrift_barcodes
  FOR SELECT
  TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM public.memberships m
  WHERE ((m.tenant_id = thrift_barcodes.tenant_id) AND (lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.is_active = true)))));

CREATE POLICY write_thrift_barcodes ON public.thrift_barcodes
  TO authenticated
  USING (public.membership_has_module_action(tenant_id, 'thrift_barcode'::text, 'edit'::text));

ALTER SEQUENCE public.thrift_barcodes_id_seq OWNED BY public.thrift_barcodes.id;

ALTER TABLE public.thrift_barcodes
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.thrift_barcodes
  ADD CONSTRAINT thrift_barcodes_barcode_id_tenant_unique UNIQUE (tenant_id, barcode_id);

ALTER TABLE public.thrift_barcodes
  ADD CONSTRAINT thrift_barcodes_is_printed_check CHECK (is_printed = ANY (ARRAY[0, 1]));

ALTER TABLE public.thrift_barcodes
  ADD CONSTRAINT thrift_barcodes_pkey PRIMARY KEY (id);

ALTER TABLE public.thrift_barcodes
  ADD CONSTRAINT thrift_barcodes_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.thrift_barcodes TO anon;

GRANT ALL ON public.thrift_barcodes TO authenticated;

GRANT ALL ON public.thrift_barcodes TO service_role;