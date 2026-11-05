CREATE TABLE public.tenant_data_purge_logs (
  id                  uuid                     DEFAULT gen_random_uuid() NOT NULL,
  parent_tenant_id    bigint                   NOT NULL,
  target_tenant_id    bigint                   NOT NULL,
  scope               text                     NOT NULL,
  executed_by         uuid,
  executor_email      text                     NOT NULL,
  confirmation_phrase text                     NOT NULL,
  deleted_counts      jsonb                    DEFAULT '{}'::jsonb NOT NULL,
  created_at          timestamp with time zone DEFAULT now() NOT NULL
);

CREATE INDEX idx_tenant_data_purge_logs_target ON public.tenant_data_purge_logs (target_tenant_id);

CREATE INDEX idx_tenant_data_purge_logs_parent ON public.tenant_data_purge_logs (parent_tenant_id);

CREATE POLICY tenant_data_purge_logs_select ON public.tenant_data_purge_logs
  FOR SELECT
  TO authenticated
  USING ((public.is_superadmin() OR public.user_can_manage_parent_tenant(parent_tenant_id)));

ALTER TABLE public.tenant_data_purge_logs
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.tenant_data_purge_logs
  ADD CONSTRAINT tenant_data_purge_logs_executed_by_fkey FOREIGN KEY (executed_by) REFERENCES auth.users(id);

ALTER TABLE public.tenant_data_purge_logs
  ADD CONSTRAINT tenant_data_purge_logs_pkey PRIMARY KEY (id);

ALTER TABLE public.tenant_data_purge_logs
  ADD CONSTRAINT tenant_data_purge_logs_scope_check CHECK (scope = ANY (ARRAY['all_hierarchy'::text, 'child_only'::text]));

ALTER TABLE public.tenant_data_purge_logs
  ADD CONSTRAINT tenant_data_purge_logs_parent_tenant_id_fkey FOREIGN KEY (parent_tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

ALTER TABLE public.tenant_data_purge_logs
  ADD CONSTRAINT tenant_data_purge_logs_target_tenant_id_fkey FOREIGN KEY (target_tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.tenant_data_purge_logs TO anon;

GRANT ALL ON public.tenant_data_purge_logs TO authenticated;

GRANT ALL ON public.tenant_data_purge_logs TO service_role;