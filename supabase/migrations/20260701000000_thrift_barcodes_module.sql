-- =========================================================
-- Thrift Barcode Module schema + triggers + RLS + RPC automation
-- =========================================================

begin;

-- Create public.thrift_barcodes table
create table if not exists public.thrift_barcodes (
  id bigserial primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  barcode_id text not null,
  status text not null default 'AVAILABLE',
  is_printed smallint not null default 0 check (is_printed in (0, 1)),
  inserted_by text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint thrift_barcodes_barcode_id_tenant_unique unique (tenant_id, barcode_id)
);

-- Trigger for updated_at
create trigger trg_thrift_barcodes_updated_at
before update on public.thrift_barcodes
for each row execute function public.set_updated_at();

-- Row Level Security
alter table public.thrift_barcodes enable row level security;

create policy select_thrift_barcodes on public.thrift_barcodes for select to authenticated
  using (exists (select 1 from public.memberships m where m.tenant_id = thrift_barcodes.tenant_id and lower(trim(m.email)) = public.current_user_email() and m.is_active = true));

create policy write_thrift_barcodes on public.thrift_barcodes for all to authenticated
  using (exists (select 1 from public.memberships m where m.tenant_id = thrift_barcodes.tenant_id and lower(trim(m.email)) = public.current_user_email() and m.is_active = true and m.role in ('admin', 'staff')));

-- Grants
grant select, insert, update, delete on table public.thrift_barcodes to authenticated;
grant usage, select on sequence public.thrift_barcodes_id_seq to authenticated;

-- Seed the module catalog
insert into public.modules (
  key,
  name,
  description,
  is_active
)
values (
  'thrift_barcode',
  'Thrift Barcode',
  'Manage and print barcodes in bulk.',
  true
)
on conflict (key) do update
set
  name = excluded.name,
  description = excluded.description,
  is_active = excluded.is_active;

-- RPC for bulk generation
create or replace function public.generate_thrift_barcodes(
  p_tenant_id bigint,
  p_prefix text,
  p_year text,
  p_quantity integer,
  p_inserted_by text
)
returns text[]
language plpgsql
security definer
as $$
declare
  v_max_seq integer := 0;
  v_barcode_id text;
  v_generated text[] := array[]::text[];
  i integer;
begin
  -- Advisory lock to prevent race conditions on sequence generation for this tenant
  perform pg_advisory_xact_lock(p_tenant_id);

  -- Validate inputs
  if length(p_prefix) <> 2 then
    raise exception 'Prefix must be exactly 2 characters long';
  end if;
  if length(p_year) <> 2 then
    raise exception 'Year must be exactly 2 characters long';
  end if;
  if p_quantity not in (50, 100, 150, 200, 300, 400, 500) then
    raise exception 'Quantity must be one of 50, 100, 150, 200, 300, 400, 500';
  end if;

  -- Find the max sequence number for this prefix and year for the tenant.
  -- e.g. AA-26-000001
  select coalesce(max(substring(barcode_id from 7)::integer), 0) into v_max_seq
  from public.thrift_barcodes
  where tenant_id = p_tenant_id
    and barcode_id like p_prefix || '-' || p_year || '-%';

  -- Loop and insert
  for i in 1..p_quantity loop
    v_barcode_id := p_prefix || '-' || p_year || '-' || lpad((v_max_seq + i)::text, 6, '0');
    
    insert into public.thrift_barcodes (
      tenant_id,
      barcode_id,
      status,
      is_printed,
      inserted_by
    )
    values (
      p_tenant_id,
      v_barcode_id,
      'AVAILABLE',
      0,
      p_inserted_by
    );
    
    v_generated := array_append(v_generated, v_barcode_id);
  end loop;

  return v_generated;
end;
$$;

grant execute on function public.generate_thrift_barcodes(bigint, text, text, integer, text) to authenticated;

commit;
