-- Rename sellable gate status: Ready Stock → received (Draft unchanged).
-- Backfill rows + CHECK constraint + any public function bodies that hardcode Ready Stock.

begin;

-- ---------------------------------------------------------------------------
-- 1. Constraint + data
-- ---------------------------------------------------------------------------
alter table public.global_shipments
  drop constraint if exists global_shipments_status_check;

update public.global_shipments
set
  status = 'received',
  updated_at = now()
where status = 'Ready Stock';

-- Keep stock_ready in sync for any row already marked sellable under the old label
update public.global_shipments
set
  stock_ready = true,
  updated_at = now()
where status = 'received'
  and stock_ready is distinct from true;

alter table public.global_shipments
  add constraint global_shipments_status_check check (status in (
    'Draft',
    'Order Placed',
    'Proforma Generated',
    'Payment Done',
    'Delivery Date Received',
    'Uk Warehouse Delivery Received',
    'Air Shipment Date Set',
    'Airport Arrival',
    'Airport Released',
    'Warehouse Received',
    'received'
  ));

-- ---------------------------------------------------------------------------
-- 2. Patch live function bodies that still reference Ready Stock
-- ---------------------------------------------------------------------------
do $$
declare
  r record;
  def text;
begin
  for r in
    select p.oid
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prokind = 'f'
      and pg_get_functiondef(p.oid) like '%Ready Stock%'
  loop
    def := pg_get_functiondef(r.oid);
    def := replace(def, 'Ready Stock', 'received');
    execute def;
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 3. Nav copy (procurement shipment module)
-- ---------------------------------------------------------------------------
update public.modules
set
  description = 'Inbound batches: draft, cost entries, finalize, and received.',
  updated_at = now()
where key = 'global_shipment';

commit;
