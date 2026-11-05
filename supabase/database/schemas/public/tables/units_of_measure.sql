CREATE TABLE public.units_of_measure (
  id         bigint                   DEFAULT nextval('public.units_of_measure_id_seq'::regclass) NOT NULL,
  code       text                     NOT NULL,
  name       text                     NOT NULL,
  unit_type  text                     NOT NULL,
  symbol     text,
  sort_order integer                  DEFAULT 0 NOT NULL,
  is_active  boolean                  DEFAULT true NOT NULL,
  is_system  boolean                  DEFAULT false NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE INDEX units_of_measure_unit_type_idx ON public.units_of_measure (unit_type);

CREATE TRIGGER trg_units_of_measure_protect_system_rows
  BEFORE DELETE OR UPDATE ON public.units_of_measure
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_system_unit_of_measure_mutation();

CREATE TRIGGER trg_units_of_measure_updated_at
  BEFORE UPDATE ON public.units_of_measure
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY superadmin_can_manage_units_of_measure ON public.units_of_measure
  TO authenticated
  USING (public.is_superadmin())
  WITH CHECK (public.is_superadmin());

ALTER SEQUENCE public.units_of_measure_id_seq OWNED BY public.units_of_measure.id;

ALTER TABLE public.units_of_measure
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.units_of_measure
  ADD CONSTRAINT units_of_measure_code_key UNIQUE (code);

ALTER TABLE public.units_of_measure
  ADD CONSTRAINT units_of_measure_code_uppercase_check CHECK (code = upper(code));

ALTER TABLE public.units_of_measure
  ADD CONSTRAINT units_of_measure_pkey PRIMARY KEY (id);

ALTER TABLE public.units_of_measure
  ADD CONSTRAINT units_of_measure_unit_type_check CHECK (unit_type = ANY (ARRAY['weight'::text, 'count'::text, 'length'::text, 'volume'::text, 'packaging'::text]));

GRANT ALL ON public.units_of_measure TO anon;

GRANT ALL ON public.units_of_measure TO authenticated;

GRANT ALL ON public.units_of_measure TO service_role;