CREATE TABLE public.global_currencies (
  id         bigint                   DEFAULT nextval('public.global_currencies_id_seq'::regclass) NOT NULL,
  name       text                     NOT NULL,
  country    text                     NOT NULL,
  code       text                     NOT NULL,
  symbol     text                     NOT NULL,
  minor_units smallint                DEFAULT 2 NOT NULL,
  is_active  boolean                  DEFAULT true NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  is_system  boolean                  DEFAULT false NOT NULL
);

CREATE TRIGGER trg_global_currencies_protect_system_rows
  BEFORE DELETE OR UPDATE ON public.global_currencies
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_system_global_currency_mutation();

CREATE TRIGGER trg_global_currencies_updated_at
  BEFORE UPDATE ON public.global_currencies
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY manage_global_currencies ON public.global_currencies
  TO authenticated
  USING (public.is_superadmin())
  WITH CHECK (public.is_superadmin());

CREATE POLICY select_global_currencies ON public.global_currencies
  FOR SELECT
  TO authenticated
  USING ((is_active = true));

ALTER SEQUENCE public.global_currencies_id_seq OWNED BY public.global_currencies.id;

ALTER TABLE public.global_currencies
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.global_currencies
  ADD CONSTRAINT thrift_currencies_code_key UNIQUE (code);

ALTER TABLE public.global_currencies
  ADD CONSTRAINT thrift_currencies_pkey PRIMARY KEY (id);

GRANT ALL ON public.global_currencies TO anon;

GRANT ALL ON public.global_currencies TO authenticated;

GRANT ALL ON public.global_currencies TO service_role;