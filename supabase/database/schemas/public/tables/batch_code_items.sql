CREATE TABLE public.batch_code_items (
  id                 bigint                   DEFAULT nextval('public.batch_code_items_id_seq'::regclass) NOT NULL,
  list_id            bigint                   NOT NULL,
  barcode            text,
  product_code       text,
  batch_id           text,
  manufacturing_date date,
  expire_date        date,
  created_at         timestamp with time zone DEFAULT now() NOT NULL,
  updated_at         timestamp with time zone DEFAULT now() NOT NULL,
  is_arrived         boolean                  DEFAULT false NOT NULL
);

CREATE INDEX batch_code_items_barcode_idx ON public.batch_code_items (barcode)
  WHERE barcode IS NOT NULL;

CREATE INDEX batch_code_items_product_code_idx ON public.batch_code_items (product_code)
  WHERE product_code IS NOT NULL;

CREATE INDEX batch_code_items_list_idx ON public.batch_code_items (list_id);

CREATE TRIGGER trg_batch_code_items_updated_at
  BEFORE UPDATE ON public.batch_code_items
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY batch_code_items_all ON public.batch_code_items
  TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM public.batch_code_lists l
  WHERE ((l.id = batch_code_items.list_id) AND public.user_can_manage_parent_tenant(l.parent_tenant_id)))))
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.batch_code_lists l
  WHERE ((l.id = batch_code_items.list_id) AND public.user_can_manage_parent_tenant(l.parent_tenant_id)))));

CREATE POLICY batch_code_items_select ON public.batch_code_items
  FOR SELECT
  TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM public.batch_code_lists l
  WHERE ((l.id = batch_code_items.list_id) AND (public.user_can_manage_parent_tenant(l.parent_tenant_id) OR (EXISTS ( SELECT 1
           FROM public.memberships m
          WHERE ((m.tenant_id = l.parent_tenant_id) AND (lower(TRIM(BOTH FROM m.email)) = public.current_user_email()) AND (m.is_active = true)))))))));

ALTER SEQUENCE public.batch_code_items_id_seq OWNED BY public.batch_code_items.id;

ALTER TABLE public.batch_code_items
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.batch_code_items
  ADD CONSTRAINT batch_code_items_pkey PRIMARY KEY (id);

ALTER TABLE public.batch_code_items
  ADD CONSTRAINT batch_code_items_list_id_fkey FOREIGN KEY (list_id) REFERENCES public.batch_code_lists(id) ON DELETE CASCADE;

GRANT ALL ON public.batch_code_items TO anon;

GRANT ALL ON public.batch_code_items TO authenticated;

GRANT ALL ON public.batch_code_items TO service_role;