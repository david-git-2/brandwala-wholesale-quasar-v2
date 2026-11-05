CREATE TABLE public.item_tags (
  id         bigint                   DEFAULT nextval('public.item_tags_id_seq'::regclass) NOT NULL,
  item_id    bigint                   NOT NULL,
  tag_id     bigint                   NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE INDEX item_tags_item_id_idx ON public.item_tags (item_id);

CREATE INDEX item_tags_tag_id_idx ON public.item_tags (tag_id);

CREATE POLICY item_tags_all ON public.item_tags
  TO authenticated
  USING ((public.get_effective_item_role(item_id, public.current_user_email()) = ANY (ARRAY['owner'::text, 'manager'::text, 'editor'::text])));

CREATE POLICY item_tags_select ON public.item_tags
  FOR SELECT
  TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM public.items
  WHERE (items.id = item_tags.item_id))));

ALTER SEQUENCE public.item_tags_id_seq OWNED BY public.item_tags.id;

ALTER TABLE public.item_tags
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.item_tags
  ADD CONSTRAINT item_tags_item_id_tag_id_key UNIQUE (item_id, tag_id);

ALTER TABLE public.item_tags
  ADD CONSTRAINT item_tags_pkey PRIMARY KEY (id);

ALTER TABLE public.item_tags
  ADD CONSTRAINT item_tags_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.items(id) ON DELETE CASCADE;

ALTER TABLE public.item_tags
  ADD CONSTRAINT item_tags_tag_id_fkey FOREIGN KEY (tag_id) REFERENCES public.tags(id) ON DELETE CASCADE;

GRANT ALL ON public.item_tags TO anon;

GRANT ALL ON public.item_tags TO authenticated;

GRANT ALL ON public.item_tags TO service_role;