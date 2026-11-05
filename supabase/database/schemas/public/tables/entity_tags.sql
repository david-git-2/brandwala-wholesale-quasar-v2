CREATE TABLE public.entity_tags (
  id          bigint                   DEFAULT nextval('public.entity_tags_id_seq'::regclass) NOT NULL,
  tenant_id   bigint                   NOT NULL,
  tag_id      bigint                   NOT NULL,
  entity_type text                     NOT NULL,
  entity_id   text                     NOT NULL,
  created_at  timestamp with time zone DEFAULT now() NOT NULL
);

CREATE INDEX entity_tags_tenant_idx ON public.entity_tags (tenant_id);

CREATE INDEX entity_tags_entity_idx ON public.entity_tags (entity_type, entity_id);

CREATE INDEX entity_tags_tag_id_idx ON public.entity_tags (tag_id);

CREATE POLICY entity_tags_all ON public.entity_tags
  TO authenticated
  USING (public.user_can_manage_parent_tenant(tenant_id))
  WITH CHECK (public.user_can_manage_parent_tenant(tenant_id));

CREATE POLICY entity_tags_select ON public.entity_tags
  FOR SELECT
  TO authenticated
  USING ((public.user_can_manage_parent_tenant(tenant_id) OR public.has_active_tenant_membership(tenant_id)));

ALTER SEQUENCE public.entity_tags_id_seq OWNED BY public.entity_tags.id;

ALTER TABLE public.entity_tags
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.entity_tags
  ADD CONSTRAINT entity_tags_pkey PRIMARY KEY (id);

ALTER TABLE public.entity_tags
  ADD CONSTRAINT entity_tags_tenant_id_tag_id_entity_type_entity_id_key UNIQUE (tenant_id, tag_id, entity_type, entity_id);

ALTER TABLE public.entity_tags
  ADD CONSTRAINT entity_tags_tag_id_fkey FOREIGN KEY (tag_id) REFERENCES public.tags(id) ON DELETE CASCADE;

ALTER TABLE public.entity_tags
  ADD CONSTRAINT entity_tags_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.entity_tags TO anon;

GRANT ALL ON public.entity_tags TO authenticated;

GRANT ALL ON public.entity_tags TO service_role;