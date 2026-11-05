CREATE TABLE public.tags (
  id               bigint                   DEFAULT nextval('public.tags_id_seq'::regclass) NOT NULL,
  tenant_id        bigint,
  name             text                     NOT NULL,
  slug             text                     NOT NULL,
  color            text                     DEFAULT '#6366f1'::text NOT NULL,
  type             text                     DEFAULT 'general'::text NOT NULL,
  created_by_email text                     DEFAULT public.current_user_email() NOT NULL,
  created_at       timestamp with time zone DEFAULT now() NOT NULL,
  group_name       text,
  sort_order       integer,
  category_id      bigint,
  metadata         jsonb                    DEFAULT '{}'::jsonb NOT NULL,
  is_system        boolean                  DEFAULT false NOT NULL,
  is_active        boolean                  DEFAULT true NOT NULL
);

CREATE UNIQUE INDEX tags_category_slug_unique ON public.tags (category_id, slug)
  WHERE category_id IS NOT NULL;

CREATE INDEX tags_created_by_email_idx ON public.tags (created_by_email);

CREATE INDEX tags_tenant_group_idx ON public.tags (tenant_id, group_name);

CREATE INDEX tags_tenant_id_idx ON public.tags (tenant_id);

CREATE UNIQUE INDEX tags_tenant_slug_email_unique ON public.tags (tenant_id, slug, created_by_email)
  WHERE tenant_id IS NOT NULL;

CREATE POLICY tags_delete ON public.tags
  FOR DELETE
  TO authenticated
  USING (((COALESCE(is_system, false) = false) AND ((created_by_email = public.current_user_email()) OR ((tenant_id IS NOT NULL) AND public.is_tenant_admin(tenant_id)))));

CREATE POLICY tags_insert ON public.tags
  FOR INSERT
  TO authenticated
  WITH CHECK (((COALESCE(is_system, false) = false) AND ((created_by_email = public.current_user_email()) OR ((tenant_id IS NOT NULL) AND public.is_tenant_admin(tenant_id)))));

CREATE POLICY tags_select ON public.tags
  FOR SELECT
  TO authenticated
  USING (((is_system = true) OR (tenant_id IS NULL) OR ((tenant_id IS
    NOT NULL) AND public.has_active_tenant_membership(tenant_id)) OR (created_by_email = public.current_user_email())));

CREATE POLICY tags_update ON public.tags
  FOR UPDATE
  TO authenticated
  USING (((COALESCE(is_system, false) = false) AND ((created_by_email = public.current_user_email()) OR ((tenant_id IS NOT NULL) AND public.is_tenant_admin(tenant_id)))))
  WITH CHECK ((COALESCE(is_system, false) = false));

ALTER SEQUENCE public.tags_id_seq OWNED BY public.tags.id;

ALTER TABLE public.tags
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.tags
  ADD CONSTRAINT tags_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.tag_categories(id) ON DELETE CASCADE;

ALTER TABLE public.tags
  ADD CONSTRAINT tags_pkey PRIMARY KEY (id);

ALTER TABLE public.tags
  ADD CONSTRAINT tags_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.tags TO anon;

GRANT ALL ON public.tags TO authenticated;

GRANT ALL ON public.tags TO service_role;