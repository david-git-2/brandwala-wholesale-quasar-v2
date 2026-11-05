CREATE TABLE public.item_permissions (
  id         bigint                   DEFAULT nextval('public.item_permissions_id_seq'::regclass) NOT NULL,
  item_id    bigint                   NOT NULL,
  user_email text                     NOT NULL,
  role       text                     NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE INDEX item_permissions_user_email_idx ON public.item_permissions (user_email);

CREATE INDEX item_permissions_item_id_idx ON public.item_permissions (item_id);

CREATE POLICY item_permissions_all ON public.item_permissions
  TO authenticated
  USING ((public.get_effective_item_role(item_id, public.current_user_email()) = ANY (ARRAY['owner'::text, 'manager'::text])));

CREATE POLICY item_permissions_select ON public.item_permissions
  FOR SELECT
  TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM public.items
  WHERE (items.id = item_permissions.item_id))));

ALTER SEQUENCE public.item_permissions_id_seq OWNED BY public.item_permissions.id;

ALTER TABLE public.item_permissions
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.item_permissions
  ADD CONSTRAINT item_permissions_item_id_user_email_key UNIQUE (item_id, user_email);

ALTER TABLE public.item_permissions
  ADD CONSTRAINT item_permissions_pkey PRIMARY KEY (id);

ALTER TABLE public.item_permissions
  ADD CONSTRAINT item_permissions_role_check CHECK (role = ANY (ARRAY['owner'::text, 'manager'::text, 'editor'::text, 'viewer'::text, 'commenter'::text]));

ALTER TABLE public.item_permissions
  ADD CONSTRAINT item_permissions_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.items(id) ON DELETE CASCADE;

GRANT ALL ON public.item_permissions TO anon;

GRANT ALL ON public.item_permissions TO authenticated;

GRANT ALL ON public.item_permissions TO service_role;