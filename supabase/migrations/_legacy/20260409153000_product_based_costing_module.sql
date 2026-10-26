begin;

-- parent table

create table if not exists public.product_based_costing_files (
  id bigserial primary key,
  tenant_id bigint null references public.tenants(id) on delete cascade,

  name text null,
  order_for text null,
  note text null,
  cargo_rate_kg_gbp numeric(12,4) null,
  profit_rate numeric(12,4) null,
  conversion_rate numeric(12,6) null,
  status text null,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists product_based_costing_files_tenant_id_idx
  on public.product_based_costing_files (tenant_id);

create index if not exists product_based_costing_files_status_idx
  on public.product_based_costing_files (status);

create index if not exists product_based_costing_files_name_idx
  on public.product_based_costing_files (name);

-- child table

create table if not exists public.product_based_costing_items (
  id bigserial primary key,
  product_based_costing_file_id bigint null references public.product_based_costing_files(id) on delete cascade,

  name text null,
  image_url text null,
  quantity numeric(12,3) null,
  barcode text null,
  product_code text null,
  web_link text null,
  price_gbp numeric(12,2) null,
  product_weight numeric(12,3) null,
  package_weight numeric(12,3) null,
  offer_price numeric(12,2) null,
  status text null,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists product_based_costing_items_file_id_idx
  on public.product_based_costing_items (product_based_costing_file_id);

create index if not exists product_based_costing_items_name_idx
  on public.product_based_costing_items (name);

create index if not exists product_based_costing_items_barcode_idx
  on public.product_based_costing_items (barcode);

create index if not exists product_based_costing_items_product_code_idx
  on public.product_based_costing_items (product_code);

create index if not exists product_based_costing_items_status_idx
  on public.product_based_costing_items (status);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_product_based_costing_files_set_updated_at
  on public.product_based_costing_files;

create trigger trg_product_based_costing_files_set_updated_at
before update on public.product_based_costing_files
for each row
execute function public.set_updated_at();

drop trigger if exists trg_product_based_costing_items_set_updated_at
  on public.product_based_costing_items;

create trigger trg_product_based_costing_items_set_updated_at
before update on public.product_based_costing_items
for each row
execute function public.set_updated_at();

grant select, insert, update, delete
on public.product_based_costing_files
to authenticated;

grant usage, select
on sequence public.product_based_costing_files_id_seq
to authenticated;

grant select, insert, update, delete
on public.product_based_costing_items
to authenticated;

grant usage, select
on sequence public.product_based_costing_items_id_seq
to authenticated;

create or replace function public.can_view_costing_internal(
  p_tenant_id bigint
)
returns boolean
language sql
stable
as $$
  select
    public.is_superadmin()
    or exists (
      select 1
      from public.memberships m
      where m.tenant_id = p_tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
        and m.role in ('admin', 'staff', 'viewer')
    )
$$;

create or replace function public.can_manage_costing(
  p_tenant_id bigint
)
returns boolean
language sql
stable
as $$
  select
    public.is_superadmin()
    or exists (
      select 1
      from public.memberships m
      where m.tenant_id = p_tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
        and m.role in ('admin', 'staff')
    )
$$;

create or replace function public.can_view_costing_item(
  p_file_id bigint
)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.product_based_costing_files f
    where f.id = p_file_id
      and public.can_view_costing_internal(f.tenant_id)
  )
$$;

create or replace function public.can_manage_costing_item(
  p_file_id bigint
)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.product_based_costing_files f
    where f.id = p_file_id
      and public.can_manage_costing(f.tenant_id)
  )
$$;

grant execute on function public.can_view_costing_internal(bigint) to authenticated;
grant execute on function public.can_manage_costing(bigint) to authenticated;
grant execute on function public.can_view_costing_item(bigint) to authenticated;
grant execute on function public.can_manage_costing_item(bigint) to authenticated;

alter table public.product_based_costing_files enable row level security;
alter table public.product_based_costing_items enable row level security;

drop policy if exists "product_based_costing_files_select"
on public.product_based_costing_files;

create policy "product_based_costing_files_select"
on public.product_based_costing_files
for select
to authenticated
using (
  public.can_view_costing_internal(tenant_id)
);

drop policy if exists "product_based_costing_files_insert"
on public.product_based_costing_files;

create policy "product_based_costing_files_insert"
on public.product_based_costing_files
for insert
to authenticated
with check (
  public.can_manage_costing(tenant_id)
);

drop policy if exists "product_based_costing_files_update"
on public.product_based_costing_files;

create policy "product_based_costing_files_update"
on public.product_based_costing_files
for update
to authenticated
using (
  public.can_manage_costing(tenant_id)
)
with check (
  public.can_manage_costing(tenant_id)
);

drop policy if exists "product_based_costing_files_delete"
on public.product_based_costing_files;

create policy "product_based_costing_files_delete"
on public.product_based_costing_files
for delete
to authenticated
using (
  public.can_manage_costing(tenant_id)
);

drop policy if exists "product_based_costing_items_select"
on public.product_based_costing_items;

create policy "product_based_costing_items_select"
on public.product_based_costing_items
for select
to authenticated
using (
  public.can_view_costing_item(product_based_costing_file_id)
);

drop policy if exists "product_based_costing_items_insert"
on public.product_based_costing_items;

create policy "product_based_costing_items_insert"
on public.product_based_costing_items
for insert
to authenticated
with check (
  public.can_manage_costing_item(product_based_costing_file_id)
);

drop policy if exists "product_based_costing_items_update"
on public.product_based_costing_items;

create policy "product_based_costing_items_update"
on public.product_based_costing_items
for update
to authenticated
using (
  public.can_manage_costing_item(product_based_costing_file_id)
)
with check (
  public.can_manage_costing_item(product_based_costing_file_id)
);

drop policy if exists "product_based_costing_items_delete"
on public.product_based_costing_items;

create policy "product_based_costing_items_delete"
on public.product_based_costing_items
for delete
to authenticated
using (
  public.can_manage_costing_item(product_based_costing_file_id)
);

commit;
