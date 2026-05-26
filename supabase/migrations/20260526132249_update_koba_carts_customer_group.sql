-- 1. Drop old RLS policies first because they depend on user_email

drop policy if exists "koba_carts_select" on public.koba_carts;
drop policy if exists "koba_carts_insert" on public.koba_carts;
drop policy if exists "koba_carts_update" on public.koba_carts;
drop policy if exists "koba_carts_delete" on public.koba_carts;

-- 2. Drop old constraints

alter table public.koba_carts
  drop constraint if exists uq_koba_carts_user_market;

alter table public.koba_carts
  drop constraint if exists koba_carts_status_check;

-- 3. Drop old indexes

drop index if exists public.koba_carts_user_email_idx;
drop index if exists public.koba_carts_market_id_idx;

-- 4. Change columns

alter table public.koba_carts
  drop column if exists user_email,
  drop column if exists market_id,
  drop column if exists status,
  add column if not exists customer_group_id bigint null;

-- 5. Add customer group foreign key

alter table public.koba_carts
  add constraint koba_carts_customer_group_id_fkey
  foreign key (customer_group_id)
  references public.customer_groups (id)
  on delete set null;

create index if not exists koba_carts_customer_group_id_idx
on public.koba_carts using btree (customer_group_id);

-- 6. Recreate simple RLS policies

alter table public.koba_carts enable row level security;

create policy "koba_carts_select"
on public.koba_carts
for select
to authenticated
using (
  is_superadmin()
  or is_tenant_admin(tenant_id)
);

create policy "koba_carts_insert"
on public.koba_carts
for insert
to authenticated
with check (
  is_superadmin()
  or is_tenant_admin(tenant_id)
);

create policy "koba_carts_update"
on public.koba_carts
for update
to authenticated
using (
  is_superadmin()
  or is_tenant_admin(tenant_id)
)
with check (
  is_superadmin()
  or is_tenant_admin(tenant_id)
);

create policy "koba_carts_delete"
on public.koba_carts
for delete
to authenticated
using (
  is_superadmin()
  or is_tenant_admin(tenant_id)
);