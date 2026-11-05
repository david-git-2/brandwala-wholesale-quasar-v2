CREATE TABLE public.payment_methods (
  id         bigint                   DEFAULT nextval('public.payment_methods_id_seq'::regclass) NOT NULL,
  code       text                     NOT NULL,
  name       text                     NOT NULL,
  category   text                     NOT NULL,
  scope      text                     NOT NULL,
  sort_order integer                  DEFAULT 0 NOT NULL,
  is_active  boolean                  DEFAULT true NOT NULL,
  is_system  boolean                  DEFAULT false NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE INDEX payment_methods_category_idx ON public.payment_methods (category);

CREATE INDEX payment_methods_scope_idx ON public.payment_methods (scope);

CREATE TRIGGER trg_payment_methods_protect_system_rows
  BEFORE DELETE OR UPDATE ON public.payment_methods
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_system_payment_method_mutation();

CREATE TRIGGER trg_payment_methods_updated_at
  BEFORE UPDATE ON public.payment_methods
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY superadmin_can_manage_payment_methods ON public.payment_methods
  TO authenticated
  USING (public.is_superadmin())
  WITH CHECK (public.is_superadmin());

ALTER SEQUENCE public.payment_methods_id_seq OWNED BY public.payment_methods.id;

ALTER TABLE public.payment_methods
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.payment_methods
  ADD CONSTRAINT payment_methods_category_check CHECK (category = ANY (ARRAY['bd_mobile_wallet'::text, 'bd_bank'::text, 'bd_cash'::text, 'card'::text, 'international'::text]));

ALTER TABLE public.payment_methods
  ADD CONSTRAINT payment_methods_code_key UNIQUE (code);

ALTER TABLE public.payment_methods
  ADD CONSTRAINT payment_methods_code_uppercase_check CHECK (code = upper(code));

ALTER TABLE public.payment_methods
  ADD CONSTRAINT payment_methods_pkey PRIMARY KEY (id);

ALTER TABLE public.payment_methods
  ADD CONSTRAINT payment_methods_scope_check CHECK (scope = ANY (ARRAY['bd'::text, 'international'::text, 'both'::text]));

GRANT ALL ON public.payment_methods TO anon;

GRANT ALL ON public.payment_methods TO authenticated;

GRANT ALL ON public.payment_methods TO service_role;