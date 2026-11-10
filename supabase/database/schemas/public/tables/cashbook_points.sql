CREATE TABLE public.cashbook_points (
  id                      bigint                     GENERATED ALWAYS AS IDENTITY NOT NULL,
  parent_tenant_id        bigint                     NOT NULL,
  cashbook_account_id     bigint                     NOT NULL,
  code                    text                       NOT NULL,
  name                    text                       NOT NULL,
  is_active               boolean                    DEFAULT true NOT NULL,
  created_at              timestamp with time zone   DEFAULT now() NOT NULL,
  updated_at              timestamp with time zone   DEFAULT now() NOT NULL
);

CREATE INDEX cashbook_points_account_active_idx ON public.cashbook_points (cashbook_account_id)
  WHERE is_active = true;

CREATE INDEX cashbook_points_parent_tenant_id_idx ON public.cashbook_points (parent_tenant_id);

CREATE POLICY cashbook_points_authenticated_policy ON public.cashbook_points
  TO authenticated
  USING (true)
  WITH CHECK (true);

COMMENT ON TABLE public.cashbook_points IS 'Place for tenant-held cash (till, safe, bank, fintech). No currency on the point; on-hand cash is cashbook_point_pots.';

ALTER TABLE public.cashbook_points
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.cashbook_points
  ADD CONSTRAINT cashbook_points_account_code_key UNIQUE (cashbook_account_id, code);

ALTER TABLE public.cashbook_points
  ADD CONSTRAINT cashbook_points_cashbook_account_id_fkey FOREIGN KEY (cashbook_account_id) REFERENCES public.cashbook_accounts(id) ON DELETE CASCADE;

ALTER TABLE public.cashbook_points
  ADD CONSTRAINT cashbook_points_code_trimmed CHECK (btrim(code) <> ''::text);

ALTER TABLE public.cashbook_points
  ADD CONSTRAINT cashbook_points_name_trimmed CHECK (btrim(name) <> ''::text);

ALTER TABLE public.cashbook_points
  ADD CONSTRAINT cashbook_points_pkey PRIMARY KEY (id);

ALTER TABLE public.cashbook_points
  ADD CONSTRAINT cashbook_points_parent_tenant_id_fkey FOREIGN KEY (parent_tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.cashbook_points TO anon;

GRANT ALL ON public.cashbook_points TO authenticated;

GRANT ALL ON public.cashbook_points TO service_role;
