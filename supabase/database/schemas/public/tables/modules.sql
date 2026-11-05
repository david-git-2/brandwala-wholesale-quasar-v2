CREATE TABLE public.modules (
  id                bigint                   DEFAULT nextval('public.modules_id_seq'::regclass) NOT NULL,
  key               text                     NOT NULL,
  name              text                     NOT NULL,
  description       text,
  is_active         boolean                  DEFAULT true NOT NULL,
  created_at        timestamp with time zone DEFAULT now() NOT NULL,
  updated_at        timestamp with time zone DEFAULT now() NOT NULL,
  parent_module_key text
);

CREATE INDEX modules_parent_module_key_idx ON public.modules (parent_module_key);

CREATE TRIGGER trg_modules_updated_at
  BEFORE UPDATE ON public.modules
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY superadmin_can_manage_modules ON public.modules
  TO authenticated
  USING (public.is_superadmin())
  WITH CHECK (public.is_superadmin());

ALTER SEQUENCE public.modules_id_seq OWNED BY public.modules.id;

ALTER TABLE public.modules
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.modules
  ADD CONSTRAINT modules_key_key UNIQUE (key);

ALTER TABLE public.modules
  ADD CONSTRAINT modules_parent_module_key_fkey FOREIGN KEY (parent_module_key) REFERENCES public.modules(key) ON DELETE SET NULL;

ALTER TABLE public.modules
  ADD CONSTRAINT modules_pkey PRIMARY KEY (id);

GRANT ALL ON public.modules TO anon;

GRANT ALL ON public.modules TO authenticated;

GRANT ALL ON public.modules TO service_role;