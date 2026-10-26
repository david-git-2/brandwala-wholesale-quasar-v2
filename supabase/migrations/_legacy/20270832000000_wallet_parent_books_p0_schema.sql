-- P0: wallet parent books columns + backfill (WALLET_PARENT_BOOKS_IMPLEMENTATION.md)

-- Step B: add columns
ALTER TABLE public.wallet_accounts
  ADD COLUMN IF NOT EXISTS parent_tenant_id bigint;

ALTER TABLE public.universal_wallet_ledger
  ADD COLUMN IF NOT EXISTS parent_tenant_id bigint,
  ADD COLUMN IF NOT EXISTS operating_tenant_id bigint;

-- Step C: backfill
UPDATE public.universal_wallet_ledger u
SET
  operating_tenant_id = u.tenant_id,
  parent_tenant_id = public.resolve_parent_tenant_id(u.tenant_id)
WHERE u.operating_tenant_id IS NULL;

UPDATE public.wallet_accounts wa
SET parent_tenant_id = public.resolve_parent_tenant_id(wa.tenant_id)
WHERE wa.parent_tenant_id IS NULL;

-- Step D: merge child tenant cash into parent pool
INSERT INTO public.wallet_accounts (
  tenant_id, parent_tenant_id, entity_type, entity_id, currency_code,
  available_balance, pending_balance, locked_balance
)
SELECT DISTINCT
  c.parent_tenant_id,
  c.parent_tenant_id,
  'tenant',
  c.parent_tenant_id,
  c.currency_code,
  0, 0, 0
FROM public.wallet_accounts wa
JOIN public.tenants t ON t.id = wa.tenant_id
CROSS JOIN LATERAL (
  SELECT public.resolve_parent_tenant_id(wa.tenant_id) AS parent_tenant_id, wa.currency_code
) c
WHERE wa.entity_type = 'tenant'
  AND t.parent_id IS NOT NULL
  AND wa.entity_id = wa.tenant_id
ON CONFLICT (tenant_id, entity_type, entity_id, currency_code) DO NOTHING;

UPDATE public.wallet_accounts parent
SET
  available_balance = parent.available_balance + child.available_balance,
  pending_balance = parent.pending_balance + child.pending_balance,
  locked_balance = parent.locked_balance + child.locked_balance,
  updated_at = now()
FROM public.wallet_accounts child
JOIN public.tenants t ON t.id = child.tenant_id
WHERE child.entity_type = 'tenant'
  AND t.parent_id IS NOT NULL
  AND child.entity_id = child.tenant_id
  AND parent.parent_tenant_id = public.resolve_parent_tenant_id(child.tenant_id)
  AND parent.entity_type = 'tenant'
  AND parent.entity_id = parent.parent_tenant_id
  AND parent.currency_code = child.currency_code;

DELETE FROM public.wallet_accounts child
WHERE child.entity_type = 'tenant'
  AND child.entity_id = child.tenant_id
  AND EXISTS (
    SELECT 1 FROM public.tenants t
    WHERE t.id = child.tenant_id AND t.parent_id IS NOT NULL
  );

-- Step E: fix ledger tenant entity_id + stamp migration metadata
UPDATE public.universal_wallet_ledger u
SET entity_id = u.parent_tenant_id
WHERE u.entity_type = 'tenant'
  AND u.entity_id = u.operating_tenant_id
  AND u.entity_id <> u.parent_tenant_id;

UPDATE public.universal_wallet_ledger
SET metadata = metadata || jsonb_build_object(
  'migration', 'wallet_parent_books_2026',
  'migrated_at', now()
)
WHERE parent_tenant_id IS NOT NULL
  AND NOT (metadata ? 'migration');

-- Keep tenant_id = books on accounts for legacy mid-deploy reads
UPDATE public.wallet_accounts
SET tenant_id = parent_tenant_id
WHERE parent_tenant_id IS NOT NULL
  AND tenant_id IS DISTINCT FROM parent_tenant_id;

-- Step G: constraints + indexes
ALTER TABLE public.universal_wallet_ledger
  ALTER COLUMN parent_tenant_id SET NOT NULL,
  ALTER COLUMN operating_tenant_id SET NOT NULL;

ALTER TABLE public.wallet_accounts
  ALTER COLUMN parent_tenant_id SET NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_wallet_accounts_parent_book
  ON public.wallet_accounts (parent_tenant_id, entity_type, entity_id, currency_code);

CREATE INDEX IF NOT EXISTS idx_uwl_parent_book_lookup
  ON public.universal_wallet_ledger (parent_tenant_id, entity_type, entity_id, created_at DESC, id DESC);

CREATE INDEX IF NOT EXISTS idx_uwl_parent_operating_created
  ON public.universal_wallet_ledger (parent_tenant_id, operating_tenant_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_uwl_operating_source
  ON public.universal_wallet_ledger (operating_tenant_id, source_type, source_id);

ALTER TABLE public.wallet_accounts
  ADD CONSTRAINT wallet_accounts_parent_tenant_id_fkey
  FOREIGN KEY (parent_tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

ALTER TABLE public.universal_wallet_ledger
  ADD CONSTRAINT universal_wallet_ledger_parent_tenant_id_fkey
  FOREIGN KEY (parent_tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

ALTER TABLE public.universal_wallet_ledger
  ADD CONSTRAINT universal_wallet_ledger_operating_tenant_id_fkey
  FOREIGN KEY (operating_tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

-- Books helper alias
CREATE OR REPLACE FUNCTION public.wallet_books_tenant_id(p_tenant_id bigint)
RETURNS bigint
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.resolve_parent_tenant_id(p_tenant_id);
$$;
