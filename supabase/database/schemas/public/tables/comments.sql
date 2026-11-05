CREATE TABLE public.comments (
  id                bigint                   DEFAULT nextval('public.comments_id_seq'::regclass) NOT NULL,
  item_id           bigint                   NOT NULL,
  parent_comment_id bigint,
  user_email        text                     DEFAULT public.current_user_email() NOT NULL,
  body              text                     NOT NULL,
  created_at        timestamp with time zone DEFAULT now() NOT NULL,
  updated_at        timestamp with time zone DEFAULT now() NOT NULL,
  deleted_at        timestamp with time zone
);

CREATE INDEX comments_item_id_idx ON public.comments (item_id);

CREATE INDEX comments_parent_comment_id_idx ON public.comments (parent_comment_id);

CREATE TRIGGER trg_comments_updated_at
  BEFORE UPDATE ON public.comments
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY comments_delete ON public.comments
  FOR DELETE
  TO authenticated
  USING (((user_email = public.current_user_email()) OR (public.get_effective_item_role(item_id, public.current_user_email()) = ANY (ARRAY['owner'::text, 'manager'::text]))));

CREATE POLICY comments_insert ON public.comments
  FOR INSERT
  TO authenticated
  WITH CHECK ((public.get_effective_item_role(item_id, public.current_user_email()) = ANY (ARRAY['owner'::text, 'manager'::text, 'editor'::text, 'commenter'::text])));

CREATE POLICY comments_update ON public.comments
  FOR UPDATE
  TO authenticated
  USING (((user_email = public.current_user_email()) OR (public.get_effective_item_role(item_id, public.current_user_email()) = ANY (ARRAY['owner'::text, 'manager'::text]))));

CREATE POLICY comments_select ON public.comments
  FOR SELECT
  TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM public.items
  WHERE (items.id = comments.item_id))));

ALTER SEQUENCE public.comments_id_seq OWNED BY public.comments.id;

ALTER TABLE public.comments
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.comments
  ADD CONSTRAINT comments_pkey PRIMARY KEY (id);

ALTER TABLE public.comments
  ADD CONSTRAINT comments_parent_comment_id_fkey FOREIGN KEY (parent_comment_id) REFERENCES public.comments(id) ON DELETE CASCADE;

ALTER TABLE public.comments
  ADD CONSTRAINT comments_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.items(id) ON DELETE CASCADE;

GRANT ALL ON public.comments TO anon;

GRANT ALL ON public.comments TO authenticated;

GRANT ALL ON public.comments TO service_role;