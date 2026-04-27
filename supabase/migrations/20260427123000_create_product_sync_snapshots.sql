-- =========================================================
-- Product sync snapshots for rollback (7-day retention)
-- =========================================================

create table if not exists public.product_sync_snapshots (
  id bigserial primary key,
  run_id text not null,
  captured_at timestamptz not null default now(),
  expires_at timestamptz not null,
  tenant_id bigint null,
  vendor_code text not null,
  market_code text not null,
  product_id bigint not null,
  barcode text null,
  product_code text null,
  row_data jsonb not null
);

create index if not exists product_sync_snapshots_run_id_idx
  on public.product_sync_snapshots (run_id);

create index if not exists product_sync_snapshots_expires_at_idx
  on public.product_sync_snapshots (expires_at);

create index if not exists product_sync_snapshots_scope_idx
  on public.product_sync_snapshots (tenant_id, vendor_code, market_code);

create index if not exists product_sync_snapshots_product_id_idx
  on public.product_sync_snapshots (product_id);

revoke all on table public.product_sync_snapshots from anon, authenticated;
revoke all on sequence public.product_sync_snapshots_id_seq from anon, authenticated;

grant select, insert, delete on table public.product_sync_snapshots to service_role;
grant usage, select on sequence public.product_sync_snapshots_id_seq to service_role;

