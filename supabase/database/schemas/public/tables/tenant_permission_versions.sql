CREATE TABLE public.tenant_permission_versions (
  tenant_id  bigint                   NOT NULL,
  version    bigint                   DEFAULT 1 NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE POLICY "Allow authenticated users to read permission versions" ON public.tenant_permission_versions
  FOR SELECT
  TO authenticated
  USING (true);

ALTER TABLE public.tenant_permission_versions
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.tenant_permission_versions
  ADD CONSTRAINT tenant_permission_versions_pkey PRIMARY KEY (tenant_id);

ALTER TABLE public.tenant_permission_versions
  ADD CONSTRAINT tenant_permission_versions_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.tenant_permission_versions TO anon;

GRANT ALL ON public.tenant_permission_versions TO authenticated;

GRANT ALL ON public.tenant_permission_versions TO service_role;