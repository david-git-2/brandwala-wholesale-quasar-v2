CREATE TABLE public.markets (
  id         bigint                   DEFAULT nextval('public.markets_id_seq'::regclass) NOT NULL,
  name       text                     NOT NULL,
  code       text                     NOT NULL,
  is_active  boolean                  DEFAULT true NOT NULL,
  is_system  boolean                  DEFAULT false NOT NULL,
  region     text                     NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE INDEX markets_region_idx ON public.markets (region);

CREATE INDEX markets_code_idx ON public.markets (code);

CREATE TRIGGER trg_markets_protect_system_rows
  BEFORE DELETE OR UPDATE ON public.markets
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_system_market_mutation();

CREATE TRIGGER trg_markets_updated_at
  BEFORE UPDATE ON public.markets
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY superadmin_can_manage_markets ON public.markets
  TO authenticated
  USING (public.is_superadmin())
  WITH CHECK (public.is_superadmin());

ALTER SEQUENCE public.markets_id_seq OWNED BY public.markets.id;

ALTER TABLE public.markets
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.markets
  ADD CONSTRAINT markets_code_key UNIQUE (code);

ALTER TABLE public.markets
  ADD CONSTRAINT markets_code_uppercase_check CHECK (code = upper(code));

ALTER TABLE public.markets
  ADD CONSTRAINT markets_pkey PRIMARY KEY (id);

GRANT ALL ON public.markets TO anon;

GRANT ALL ON public.markets TO authenticated;

GRANT ALL ON public.markets TO service_role;