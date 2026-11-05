CREATE TABLE public.activity_logs (
  id         bigint                   DEFAULT nextval('public.activity_logs_id_seq'::regclass) NOT NULL,
  item_id    bigint                   NOT NULL,
  user_email text                     DEFAULT public.current_user_email() NOT NULL,
  action     text                     NOT NULL,
  old_value  text,
  new_value  text,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE INDEX activity_logs_item_id_idx ON public.activity_logs (item_id);

CREATE POLICY activity_logs_insert ON public.activity_logs
  FOR INSERT
  TO authenticated
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.items
  WHERE (items.id = activity_logs.item_id))));

CREATE POLICY activity_logs_select ON public.activity_logs
  FOR SELECT
  TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM public.items
  WHERE (items.id = activity_logs.item_id))));

ALTER SEQUENCE public.activity_logs_id_seq OWNED BY public.activity_logs.id;

ALTER TABLE public.activity_logs
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.activity_logs
  ADD CONSTRAINT activity_logs_pkey PRIMARY KEY (id);

ALTER TABLE public.activity_logs
  ADD CONSTRAINT activity_logs_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.items(id) ON DELETE CASCADE;

GRANT ALL ON public.activity_logs TO anon;

GRANT ALL ON public.activity_logs TO authenticated;

GRANT ALL ON public.activity_logs TO service_role;