-- Drop pre-sync rollback table (PC/WTS upload no longer writes snapshots).

drop trigger if exists trg_product_sync_snapshots_sync_vendor_reference_fields
  on public.product_sync_snapshots;

drop table if exists public.product_sync_snapshots;
