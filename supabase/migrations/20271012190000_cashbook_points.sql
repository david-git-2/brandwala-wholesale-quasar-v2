-- Tenant cash points (drawer / safe / till) under a cashbook account. Ledger hook only; no pay RPC yet.

DO $$
BEGIN
  CREATE TYPE public.cashbook_point_kind AS ENUM (
    'drawer',
    'safe',
    'bank_counter',
    'mobile',
    'other'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END
$$;

CREATE TABLE IF NOT EXISTS public.cashbook_points (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  parent_tenant_id bigint NOT NULL REFERENCES public.tenants (id) ON DELETE CASCADE,
  cashbook_account_id bigint NOT NULL REFERENCES public.cashbook_accounts (id) ON DELETE CASCADE,
  code text NOT NULL,
  name text NOT NULL,
  kind public.cashbook_point_kind DEFAULT 'drawer'::public.cashbook_point_kind NOT NULL,
  custodian_membership_id bigint REFERENCES public.memberships (id) ON DELETE SET NULL,
  is_active boolean DEFAULT true NOT NULL,
  sort_order integer DEFAULT 0 NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL,
  CONSTRAINT cashbook_points_code_trimmed CHECK (btrim(code) <> ''),
  CONSTRAINT cashbook_points_name_trimmed CHECK (btrim(name) <> ''),
  CONSTRAINT cashbook_points_account_code_key UNIQUE (cashbook_account_id, code)
);

COMMENT ON TABLE public.cashbook_points IS
  'Physical/logical place for tenant-held cash under a cashbook account (till, safe, drawer). v1: tenant operating books only; pays may tag entries later.';

CREATE INDEX IF NOT EXISTS cashbook_points_parent_tenant_id_idx
  ON public.cashbook_points USING btree (parent_tenant_id);

CREATE INDEX IF NOT EXISTS cashbook_points_account_active_idx
  ON public.cashbook_points USING btree (cashbook_account_id, sort_order)
  WHERE is_active = true;

ALTER TABLE public.cashbook_entries
  ADD COLUMN IF NOT EXISTS cashbook_point_id bigint;

ALTER TABLE public.cashbook_entries DROP CONSTRAINT IF EXISTS cashbook_entries_cashbook_point_id_fkey;
ALTER TABLE public.cashbook_entries
  ADD CONSTRAINT cashbook_entries_cashbook_point_id_fkey
  FOREIGN KEY (cashbook_point_id) REFERENCES public.cashbook_points (id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS cashbook_entries_point_lookup_idx
  ON public.cashbook_entries USING btree (cashbook_point_id, created_at DESC)
  WHERE cashbook_point_id IS NOT NULL;

ALTER TABLE public.cashbook_points ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS cashbook_points_authenticated_policy ON public.cashbook_points;
CREATE POLICY cashbook_points_authenticated_policy ON public.cashbook_points
  TO authenticated
  USING (true)
  WITH CHECK (true);

GRANT REFERENCES, TRIGGER, TRUNCATE, MAINTAIN ON TABLE public.cashbook_points TO anon;
GRANT ALL ON TABLE public.cashbook_points TO authenticated;
GRANT ALL ON TABLE public.cashbook_points TO service_role;
