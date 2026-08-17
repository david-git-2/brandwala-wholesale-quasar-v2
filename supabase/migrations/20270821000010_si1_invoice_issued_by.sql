-- SI1: Database knows who sold it.
-- issued_by_tenant_id = current tenant_id (child). Do not flip tenant_id. Do not drop parent_tenant_id.
-- Trigger keeps live create_global_invoice inserts working until SI2 writes issued_by explicitly.

begin;

-- ---------------------------------------------------------------------------
-- Header: selling sister
-- ---------------------------------------------------------------------------
alter table public.global_invoices
  add column if not exists issued_by_tenant_id bigint;

update public.global_invoices
set issued_by_tenant_id = tenant_id
where issued_by_tenant_id is null;

alter table public.global_invoices
  alter column issued_by_tenant_id set not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'global_invoices_issued_by_tenant_id_fkey'
      and conrelid = 'public.global_invoices'::regclass
  ) then
    alter table public.global_invoices
      add constraint global_invoices_issued_by_tenant_id_fkey
      foreign key (issued_by_tenant_id) references public.tenants(id);
  end if;
end $$;

create index if not exists global_invoices_issued_by_tenant_id_idx
  on public.global_invoices (issued_by_tenant_id);

-- Unique (tenant_id, invoice_no) stays as-is.

create or replace function public.global_invoices_default_issued_by_tenant_id()
returns trigger
language plpgsql
as $$
begin
  if new.issued_by_tenant_id is null then
    new.issued_by_tenant_id := new.tenant_id;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_global_invoices_default_issued_by on public.global_invoices;
create trigger trg_global_invoices_default_issued_by
before insert on public.global_invoices
for each row
execute function public.global_invoices_default_issued_by_tenant_id();

-- ---------------------------------------------------------------------------
-- Lines: shipment assign snapshot (nullable; SI4 backfills from shipment)
-- ---------------------------------------------------------------------------
alter table public.global_invoice_items
  add column if not exists assigned_child_tenant_id bigint;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'global_invoice_items_assigned_child_tenant_id_fkey'
      and conrelid = 'public.global_invoice_items'::regclass
  ) then
    alter table public.global_invoice_items
      add constraint global_invoice_items_assigned_child_tenant_id_fkey
      foreign key (assigned_child_tenant_id) references public.tenants(id);
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Audit
-- ---------------------------------------------------------------------------
do $$
begin
  assert (select count(*) from public.global_invoices where issued_by_tenant_id is null) = 0;
  assert (select count(*) from public.global_invoices where issued_by_tenant_id is distinct from tenant_id) = 0;
end $$;

commit;
