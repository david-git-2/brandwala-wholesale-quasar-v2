CREATE TABLE public.thrift_stock_images (
  id            bigint                   DEFAULT nextval('public.thrift_stock_images_id_seq'::regclass) NOT NULL,
  stock_id      bigint                   NOT NULL,
  image_url     text                     NOT NULL,
  is_primary    boolean                  DEFAULT false NOT NULL,
  inserted_by   text                     NOT NULL,
  created_at    timestamp with time zone DEFAULT now() NOT NULL,
  updated_at    timestamp with time zone DEFAULT now() NOT NULL,
  drive_file_id text
);

CREATE INDEX thrift_stock_images_stock_primary_idx ON public.thrift_stock_images (stock_id)
  WHERE is_primary = true;

CREATE TRIGGER trg_thrift_stock_images_updated_at
  BEFORE UPDATE ON public.thrift_stock_images
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY select_thrift_stock_images ON public.thrift_stock_images
  FOR SELECT
  TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM (public.thrift_stocks s
     JOIN public.memberships m ON ((m.tenant_id = s.tenant_id)))
  WHERE ((s.id = thrift_stock_images.stock_id) AND (lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.is_active = true)))));

CREATE POLICY write_thrift_stock_images ON public.thrift_stock_images
  TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM public.thrift_stocks s
  WHERE ((s.id = thrift_stock_images.stock_id) AND public.membership_has_module_action(s.tenant_id, 'thrift_stock'::text, 'edit'::text)))));

ALTER SEQUENCE public.thrift_stock_images_id_seq OWNED BY public.thrift_stock_images.id;

ALTER TABLE public.thrift_stock_images
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.thrift_stock_images
  ADD CONSTRAINT thrift_stock_images_pkey PRIMARY KEY (id);

ALTER TABLE public.thrift_stock_images
  ADD CONSTRAINT thrift_stock_images_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES public.thrift_stocks(id) ON DELETE CASCADE;

GRANT ALL ON public.thrift_stock_images TO anon;

GRANT ALL ON public.thrift_stock_images TO authenticated;

GRANT ALL ON public.thrift_stock_images TO service_role;