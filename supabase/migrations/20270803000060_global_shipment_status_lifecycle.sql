-- Collapse global_shipments.status to solid lifecycle:
-- draft | in_transit | received | cancelled
-- (doc/procurement_stock/shipment/schema.md · workflow_flow.md)
-- Mid-ops labels (UK hub, airport, Warehouse Received, …) → in_transit.
-- Progress journey tags are NOT statuses (entity_tags / shipment_progress — later).

begin;

alter table public.global_shipments
  drop constraint if exists global_shipments_status_check;

-- Draft
update public.global_shipments
set
  status = 'draft',
  updated_at = now()
where status = 'Draft';

-- All pre-receive operational statuses → in_transit
update public.global_shipments
set
  status = 'in_transit',
  updated_at = now()
where status in (
  'Order Placed',
  'Proforma Generated',
  'Payment Done',
  'Delivery Date Received',
  'Uk Warehouse Delivery Received',
  'Air Shipment Date Set',
  'Airport Arrival',
  'Airport Released',
  'Warehouse Received'
);

-- received already correct from prior migration; ensure stock_ready
update public.global_shipments
set
  stock_ready = true,
  updated_at = now()
where status = 'received'
  and stock_ready is distinct from true;

alter table public.global_shipments
  alter column status set default 'draft';

alter table public.global_shipments
  add constraint global_shipments_status_check check (
    status in ('draft', 'in_transit', 'received', 'cancelled')
  );

-- Patch public function bodies that still hardcode legacy global shipment statuses
do $$
declare
  r record;
  def text;
  new_def text;
begin
  for r in
    select p.oid, n.nspname, p.proname, pg_get_function_identity_arguments(p.oid) as args
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prokind = 'f'
      and pg_get_functiondef(p.oid) like '%global_shipment%'
      and (
        pg_get_functiondef(p.oid) like '%Warehouse Received%'
        or pg_get_functiondef(p.oid) like '%''Draft''%'
        or pg_get_functiondef(p.oid) like '%Ready Stock%'
      )
  loop
    def := pg_get_functiondef(r.oid);
    new_def := def;
    new_def := replace(new_def, 'Warehouse Received', 'in_transit');
    new_def := replace(new_def, 'Ready Stock', 'received');
    new_def := replace(new_def, '''Draft''', '''draft''');
    if new_def is distinct from def then
      execute new_def;
      raise notice 'Patched %.%(%)', r.nspname, r.proname, r.args;
    end if;
  end loop;
end $$;

commit;
