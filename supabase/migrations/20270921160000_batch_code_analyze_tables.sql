-- Batch Code Analyze: lists (per shipment/vendor) and line items.
begin;

create table if not exists public.batch_code_lists (
  id bigserial primary key,
  parent_tenant_id bigint not null references public.tenants(id) on delete cascade,
  shipment_id bigint references public.global_shipments(id) on delete cascade,
  vendor_id bigint not null references public.vendors(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists batch_code_lists_shipment_id_key
  on public.batch_code_lists (shipment_id)
  where shipment_id is not null;

create index if not exists batch_code_lists_parent_tenant_idx
  on public.batch_code_lists (parent_tenant_id);

create index if not exists batch_code_lists_vendor_idx
  on public.batch_code_lists (vendor_id);

drop trigger if exists trg_batch_code_lists_updated_at on public.batch_code_lists;
create trigger trg_batch_code_lists_updated_at
  before update on public.batch_code_lists
  for each row execute function public.set_updated_at();

create table if not exists public.batch_code_items (
  id bigserial primary key,
  list_id bigint not null references public.batch_code_lists(id) on delete cascade,
  barcode text,
  product_code text,
  batch_id text,
  manufacturing_date date,
  expire_date date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists batch_code_items_list_idx
  on public.batch_code_items (list_id);

create index if not exists batch_code_items_barcode_idx
  on public.batch_code_items (barcode)
  where barcode is not null;

create index if not exists batch_code_items_product_code_idx
  on public.batch_code_items (product_code)
  where product_code is not null;

drop trigger if exists trg_batch_code_items_updated_at on public.batch_code_items;
create trigger trg_batch_code_items_updated_at
  before update on public.batch_code_items
  for each row execute function public.set_updated_at();

alter table public.batch_code_lists enable row level security;
alter table public.batch_code_items enable row level security;

drop policy if exists batch_code_lists_select on public.batch_code_lists;
create policy batch_code_lists_select on public.batch_code_lists
  for select to authenticated
  using (
    public.user_can_manage_parent_tenant(parent_tenant_id)
    or exists (
      select 1
      from public.memberships m
      where m.tenant_id = batch_code_lists.parent_tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
    )
  );

drop policy if exists batch_code_lists_all on public.batch_code_lists;
create policy batch_code_lists_all on public.batch_code_lists
  for all to authenticated
  using (public.user_can_manage_parent_tenant(parent_tenant_id))
  with check (public.user_can_manage_parent_tenant(parent_tenant_id));

drop policy if exists batch_code_items_select on public.batch_code_items;
create policy batch_code_items_select on public.batch_code_items
  for select to authenticated
  using (
    exists (
      select 1
      from public.batch_code_lists l
      where l.id = batch_code_items.list_id
        and (
          public.user_can_manage_parent_tenant(l.parent_tenant_id)
          or exists (
            select 1
            from public.memberships m
            where m.tenant_id = l.parent_tenant_id
              and lower(trim(m.email)) = public.current_user_email()
              and m.is_active = true
          )
        )
    )
  );

drop policy if exists batch_code_items_all on public.batch_code_items;
create policy batch_code_items_all on public.batch_code_items
  for all to authenticated
  using (
    exists (
      select 1
      from public.batch_code_lists l
      where l.id = batch_code_items.list_id
        and public.user_can_manage_parent_tenant(l.parent_tenant_id)
    )
  )
  with check (
    exists (
      select 1
      from public.batch_code_lists l
      where l.id = batch_code_items.list_id
        and public.user_can_manage_parent_tenant(l.parent_tenant_id)
    )
  );

grant select, insert, update, delete on table public.batch_code_lists to authenticated;
grant select, insert, update, delete on table public.batch_code_items to authenticated;
grant usage, select on sequence public.batch_code_lists_id_seq to authenticated;
grant usage, select on sequence public.batch_code_items_id_seq to authenticated;

commit;
