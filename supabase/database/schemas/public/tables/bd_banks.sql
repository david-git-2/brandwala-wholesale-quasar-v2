CREATE TABLE public.bd_banks (
  id         bigint                   DEFAULT nextval('public.bd_banks_id_seq'::regclass) NOT NULL,
  code       text                     NOT NULL,
  name       text                     NOT NULL,
  swift_code text,
  sort_order integer                  DEFAULT 0 NOT NULL,
  is_active  boolean                  DEFAULT true NOT NULL,
  is_system  boolean                  DEFAULT false NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE INDEX bd_banks_code_idx ON public.bd_banks (code);

CREATE INDEX bd_banks_sort_order_idx ON public.bd_banks (sort_order);

CREATE TRIGGER trg_bd_banks_protect_system_rows
  BEFORE DELETE OR UPDATE ON public.bd_banks
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_system_bd_bank_mutation();

CREATE TRIGGER trg_bd_banks_updated_at
  BEFORE UPDATE ON public.bd_banks
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY superadmin_can_manage_bd_banks ON public.bd_banks
  TO authenticated
  USING (public.is_superadmin())
  WITH CHECK (public.is_superadmin());

ALTER SEQUENCE public.bd_banks_id_seq OWNED BY public.bd_banks.id;

ALTER TABLE public.bd_banks
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.bd_banks
  ADD CONSTRAINT bd_banks_code_key UNIQUE (code);

ALTER TABLE public.bd_banks
  ADD CONSTRAINT bd_banks_code_uppercase_check CHECK (code = upper(code));

ALTER TABLE public.bd_banks
  ADD CONSTRAINT bd_banks_pkey PRIMARY KEY (id);

GRANT ALL ON public.bd_banks TO anon;

GRANT ALL ON public.bd_banks TO authenticated;

GRANT ALL ON public.bd_banks TO service_role;