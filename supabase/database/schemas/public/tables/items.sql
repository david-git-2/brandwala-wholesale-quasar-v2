CREATE TABLE public.items (
  id               bigint                   DEFAULT nextval('public.items_id_seq'::regclass) NOT NULL,
  tenant_id        bigint,
  parent_id        bigint,
  type             text                     NOT NULL,
  title            text                     NOT NULL,
  content          text,
  status           text                     DEFAULT 'todo'::text NOT NULL,
  priority         text                     DEFAULT 'medium'::text NOT NULL,
  created_by_email text                     DEFAULT public.current_user_email() NOT NULL,
  due_date         timestamp with time zone,
  start_date       timestamp with time zone,
  created_at       timestamp with time zone DEFAULT now() NOT NULL,
  updated_at       timestamp with time zone DEFAULT now() NOT NULL,
  archived_at      timestamp with time zone,
  accessibility    text                     DEFAULT 'public'::text NOT NULL,
  is_markdown      boolean                  DEFAULT false NOT NULL
);

CREATE INDEX items_created_by_email_idx ON public.items (created_by_email);

CREATE INDEX items_parent_id_idx ON public.items (parent_id);

CREATE INDEX items_tenant_id_idx ON public.items (tenant_id);

CREATE TRIGGER trg_items_updated_at
  BEFORE UPDATE ON public.items
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_prevent_item_parent_cycles
  BEFORE INSERT OR UPDATE OF parent_id ON public.items
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_item_parent_cycles();

CREATE POLICY items_delete ON public.items
  FOR DELETE
  TO authenticated
  USING ((public.get_effective_item_role(id, public.current_user_email()) = ANY (ARRAY['owner'::text, 'manager'::text])));

CREATE POLICY items_insert ON public.items
  FOR INSERT
  TO authenticated
  WITH
    CHECK
    ((((parent_id IS NULL) AND ((tenant_id IS NULL) OR (public.has_active_tenant_membership(tenant_id) AND public.membership_has_module_action(tenant_id, 'tasks'::text,
    'create'::text)))) OR ((parent_id IS
    NOT NULL) AND (public.get_effective_item_role(parent_id, public.current_user_email()) = ANY (ARRAY['owner'::text, 'manager'::text, 'editor'::text])))));

CREATE POLICY items_select ON public.items
  FOR SELECT
  TO authenticated
  USING ((public.get_effective_item_role(id, public.current_user_email()) IS NOT NULL));

CREATE POLICY items_update ON public.items
  FOR UPDATE
  TO authenticated
  USING ((public.get_effective_item_role(id, public.current_user_email()) = ANY (ARRAY['owner'::text, 'manager'::text, 'editor'::text])))
  WITH CHECK ((public.get_effective_item_role(id, public.current_user_email()) = ANY (ARRAY['owner'::text, 'manager'::text, 'editor'::text])));

ALTER SEQUENCE public.items_id_seq OWNED BY public.items.id;

ALTER TABLE public.items
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.items
  ADD CONSTRAINT items_accessibility_check
    CHECK (type = 'note'::text AND (accessibility = ANY (ARRAY['public'::text, 'private'::text, 'restricted'::text])) OR type <> 'note'::text AND accessibility = 'public'::text);

ALTER TABLE public.items
  ADD CONSTRAINT items_pkey PRIMARY KEY (id);

ALTER TABLE public.items
  ADD CONSTRAINT items_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.items(id) ON DELETE CASCADE;

ALTER TABLE public.items
  ADD CONSTRAINT items_priority_check CHECK (priority = ANY (ARRAY['low'::text, 'medium'::text, 'high'::text, 'urgent'::text]));

ALTER TABLE public.items
  ADD CONSTRAINT items_status_check CHECK (status = ANY (ARRAY['todo'::text, 'in_progress'::text, 'review'::text, 'done'::text, 'blocked'::text, 'archived'::text]));

ALTER TABLE public.items
  ADD CONSTRAINT items_type_check
    CHECK (type = ANY (ARRAY['project'::text, 'module'::text, 'submodule'::text, 'task'::text, 'note'::text, 'discussion'::text, 'bug'::text, 'feature'::text]));

ALTER TABLE public.items
  ADD CONSTRAINT items_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.items TO anon;

GRANT ALL ON public.items TO authenticated;

GRANT ALL ON public.items TO service_role;