-- Migration: 20270829000200_shipment_sections.sql
-- Description: Add global_shipment_sections table, section_id on items and cost entries,
-- make global_shipments.vendor_id nullable, backfill existing shipments, and add reorder RPC.

begin;

-- ---------------------------------------------------------------------------
-- 1. Create global_shipment_sections table
-- ---------------------------------------------------------------------------

create table if not exists public.global_shipment_sections (
  id bigserial primary key,
  parent_tenant_id bigint not null references public.tenants(id) on delete cascade,
  shipment_id bigint not null references public.global_shipments(id) on delete cascade,
  vendor_id bigint not null references public.vendors(id) on delete restrict,
  title text not null,
  sort_order integer not null default 0,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint global_shipment_sections_title_not_blank check (length(trim(both from title)) > 0)
);

-- Triggers for setting updated_at on sections
drop trigger if exists trg_global_shipment_sections_updated_at on public.global_shipment_sections;
create trigger trg_global_shipment_sections_updated_at before update on public.global_shipment_sections
for each row execute function public.set_updated_at();

-- Indexes for performance
create index if not exists global_shipment_sections_shipment_idx on public.global_shipment_sections(shipment_id);
create index if not exists global_shipment_sections_parent_tenant_idx on public.global_shipment_sections(parent_tenant_id);
create index if not exists global_shipment_sections_vendor_idx on public.global_shipment_sections(vendor_id);

-- Enable RLS
alter table public.global_shipment_sections enable row level security;

-- RLS policies for global_shipment_sections
drop policy if exists global_shipment_sections_select on public.global_shipment_sections;
create policy global_shipment_sections_select on public.global_shipment_sections for select to authenticated using (
  public.user_can_manage_parent_tenant(parent_tenant_id)
  or exists (
    select 1
    from public.memberships m
    where m.tenant_id = global_shipment_sections.parent_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  )
);

drop policy if exists global_shipment_sections_all on public.global_shipment_sections;
create policy global_shipment_sections_all on public.global_shipment_sections for all to authenticated using (
  public.user_can_manage_parent_tenant(parent_tenant_id)
) with check (
  public.user_can_manage_parent_tenant(parent_tenant_id)
);

-- Grants
grant select, insert, update, delete on table public.global_shipment_sections to authenticated;
grant usage, select on sequence public.global_shipment_sections_id_seq to authenticated;

-- ---------------------------------------------------------------------------
-- 2. Alter global_shipments, global_shipment_items, and global_shipment_cost_entries
-- ---------------------------------------------------------------------------

-- Make global_shipments.vendor_id nullable (sections now hold vendor identity)
alter table public.global_shipments alter column vendor_id drop not null;

-- Add section_id to global_shipment_items
alter table public.global_shipment_items
  add column if not exists section_id bigint references public.global_shipment_sections(id) on delete set null;

create index if not exists global_shipment_items_section_idx on public.global_shipment_items(section_id);

-- Add section_id to global_shipment_cost_entries
alter table public.global_shipment_cost_entries
  add column if not exists section_id bigint references public.global_shipment_sections(id) on delete cascade;

create index if not exists global_shipment_cost_entries_section_idx on public.global_shipment_cost_entries(section_id);

-- ---------------------------------------------------------------------------
-- 3. Backfill default sections for all existing shipments
-- ---------------------------------------------------------------------------

do $$
declare
  r_ship record;
  v_vendor_id bigint;
  v_section_id bigint;
begin
  for r_ship in select id, parent_tenant_id, vendor_id, name from public.global_shipments loop
    -- Resolve a vendor for the default section
    v_vendor_id := r_ship.vendor_id;
    if v_vendor_id is null then
      v_vendor_id := public.ensure_default_vendor(r_ship.parent_tenant_id);
    end if;

    -- Create default section if none exists for this shipment
    if not exists (select 1 from public.global_shipment_sections where shipment_id = r_ship.id) then
      insert into public.global_shipment_sections (
        parent_tenant_id,
        shipment_id,
        vendor_id,
        title,
        sort_order,
        metadata
      )
      values (
        r_ship.parent_tenant_id,
        r_ship.id,
        v_vendor_id,
        'General / Section 1',
        0,
        '{}'::jsonb
      )
      returning id into v_section_id;

      -- Backfill items in this shipment with this section_id
      update public.global_shipment_items
      set section_id = v_section_id
      where shipment_id = r_ship.id
        and section_id is null;
    end if;
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Update create_shipment_draft to auto-create initial default section
-- ---------------------------------------------------------------------------

create or replace function public.create_shipment_draft(
  p_parent_tenant_id bigint,
  p_name text,
  p_type public.global_shipment_type,
  p_vendor_id bigint default null,
  p_cargo_company_id bigint default null
)
returns public.global_shipments
language plpgsql
security definer
set search_path = public
as $$
declare
  v_stock_parent bigint;
  v_vendor_id bigint;
  v_cargo_id bigint;
  v_row public.global_shipments%rowtype;
  v_section_id bigint;
begin
  if p_parent_tenant_id is null then
    raise exception 'p_parent_tenant_id is required';
  end if;

  if nullif(trim(p_name), '') is null then
    raise exception 'name is required';
  end if;

  if p_type is null then
    raise exception 'type is required';
  end if;

  v_stock_parent := public.resolve_parent_tenant_id(p_parent_tenant_id);

  if not public.user_can_manage_parent_tenant(v_stock_parent) then
    raise exception 'not allowed';
  end if;

  -- Vendor: explicit or tenant default fallback
  v_vendor_id := p_vendor_id;
  if v_vendor_id is null then
    v_vendor_id := public.ensure_default_vendor(v_stock_parent);
  else
    if not exists (
      select 1
      from public.vendors v
      where v.id = v_vendor_id
        and coalesce(v.parent_tenant_id, v.tenant_id) = v_stock_parent
    ) then
      raise exception 'vendor % does not belong to parent tenant %', v_vendor_id, v_stock_parent;
    end if;
  end if;

  -- Optional cargo company (same parent scope)
  v_cargo_id := p_cargo_company_id;
  if v_cargo_id is null then
    v_cargo_id := public.ensure_default_cargo_company(v_stock_parent);
  else
    if not exists (
      select 1
      from public.cargo_companies c
      where c.id = v_cargo_id
        and coalesce(c.parent_tenant_id, c.tenant_id) = v_stock_parent
    ) then
      raise exception 'cargo company % does not belong to parent tenant %', v_cargo_id, v_stock_parent;
    end if;
  end if;

  insert into public.global_shipments (
    parent_tenant_id,
    name,
    type,
    vendor_id,
    cargo_company_id,
    status
  )
  values (
    v_stock_parent,
    trim(p_name),
    p_type,
    v_vendor_id,
    v_cargo_id,
    'draft'
  )
  returning * into v_row;

  -- Auto-create primary default section for this shipment
  insert into public.global_shipment_sections (
    parent_tenant_id,
    shipment_id,
    vendor_id,
    title,
    sort_order,
    metadata
  )
  values (
    v_stock_parent,
    v_row.id,
    v_vendor_id,
    'Section 1',
    0,
    '{}'::jsonb
  );

  return v_row;
end;
$$;

revoke all on function public.create_shipment_draft(
  bigint, text, public.global_shipment_type, bigint, bigint
) from public;
grant execute on function public.create_shipment_draft(
  bigint, text, public.global_shipment_type, bigint, bigint
) to authenticated;
grant execute on function public.create_shipment_draft(
  bigint, text, public.global_shipment_type, bigint, bigint
) to service_role;

-- ---------------------------------------------------------------------------
-- 5. RPC: reorder_shipment_sections
-- ---------------------------------------------------------------------------

create or replace function public.reorder_shipment_sections(
  p_shipment_id bigint,
  p_section_ids bigint[]
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ship public.global_shipments;
  v_idx integer;
  v_section_id bigint;
begin
  select * into v_ship
  from public.global_shipments
  where id = p_shipment_id;

  if not found then
    raise exception 'shipment not found';
  end if;

  if not public.user_can_manage_parent_tenant(v_ship.parent_tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  if p_section_ids is null or array_length(p_section_ids, 1) is null then
    return;
  end if;

  for v_idx in 1..array_length(p_section_ids, 1) loop
    v_section_id := p_section_ids[v_idx];

    update public.global_shipment_sections
    set sort_order = v_idx - 1,
        updated_at = now()
    where id = v_section_id
      and shipment_id = p_shipment_id;
  end loop;
end;
$$;

grant execute on function public.reorder_shipment_sections(bigint, bigint[]) to authenticated;
grant execute on function public.reorder_shipment_sections(bigint, bigint[]) to service_role;

commit;
