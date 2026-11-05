CREATE TABLE public.item_assignees (
  id                bigint                   DEFAULT nextval('public.item_assignees_id_seq'::regclass) NOT NULL,
  item_id           bigint                   NOT NULL,
  user_email        text                     NOT NULL,
  assigned_by_email text                     DEFAULT public.current_user_email() NOT NULL,
  created_at        timestamp with time zone DEFAULT now() NOT NULL
);

CREATE INDEX item_assignees_user_email_idx ON public.item_assignees (user_email);

CREATE INDEX item_assignees_item_id_idx ON public.item_assignees (item_id);

CREATE TRIGGER trg_item_assignees_notify_assigned
  AFTER INSERT ON public.item_assignees
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_item_assignees_notify_assigned();

CREATE POLICY item_assignees_all ON public.item_assignees
  TO authenticated
  USING ((public.get_effective_item_role(item_id, public.current_user_email()) = ANY (ARRAY['owner'::text, 'manager'::text])));

CREATE POLICY item_assignees_select ON public.item_assignees
  FOR SELECT
  TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM public.items
  WHERE (items.id = item_assignees.item_id))));

ALTER SEQUENCE public.item_assignees_id_seq OWNED BY public.item_assignees.id;

ALTER TABLE public.item_assignees
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.item_assignees
  ADD CONSTRAINT item_assignees_item_id_user_email_key UNIQUE (item_id, user_email);

ALTER TABLE public.item_assignees
  ADD CONSTRAINT item_assignees_pkey PRIMARY KEY (id);

ALTER TABLE public.item_assignees
  ADD CONSTRAINT item_assignees_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.items(id) ON DELETE CASCADE;

GRANT ALL ON public.item_assignees TO anon;

GRANT ALL ON public.item_assignees TO authenticated;

GRANT ALL ON public.item_assignees TO service_role;