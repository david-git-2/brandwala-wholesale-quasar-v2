-- =========================================================
-- Step 2: Customer access RLS and helpers
-- Protect customer_groups and customer_group_members
-- =========================================================

create or replace function public.can_manage_customer_group(
  p_tenant_id bigint
)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select
    public.is_superadmin()
    or public.is_tenant_admin(p_tenant_id)
$$;

create or replace function public.can_manage_customer_group_member(
  p_customer_group_id bigint
)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.customer_groups cg
    where cg.id = p_customer_group_id
      and public.can_manage_customer_group(cg.tenant_id)
  )
$$;

grant execute on function public.can_manage_customer_group(bigint)
to authenticated;

grant execute on function public.can_manage_customer_group_member(bigint)
to authenticated;

alter table public.customer_groups enable row level security;
alter table public.customer_group_members enable row level security;

create policy "customer_groups_select"
on public.customer_groups
for select
to authenticated
using (
  public.can_manage_customer_group(tenant_id)
);

create policy "customer_groups_insert"
on public.customer_groups
for insert
to authenticated
with check (
  public.can_manage_customer_group(tenant_id)
);

create policy "customer_groups_update"
on public.customer_groups
for update
to authenticated
using (
  public.can_manage_customer_group(tenant_id)
)
with check (
  public.can_manage_customer_group(tenant_id)
);

create policy "customer_groups_delete"
on public.customer_groups
for delete
to authenticated
using (
  public.can_manage_customer_group(tenant_id)
);

create policy "customer_group_members_select"
on public.customer_group_members
for select
to authenticated
using (
  public.can_manage_customer_group_member(customer_group_id)
);

create policy "customer_group_members_insert"
on public.customer_group_members
for insert
to authenticated
with check (
  public.can_manage_customer_group_member(customer_group_id)
);

create policy "customer_group_members_update"
on public.customer_group_members
for update
to authenticated
using (
  public.can_manage_customer_group_member(customer_group_id)
)
with check (
  public.can_manage_customer_group_member(customer_group_id)
);

create policy "customer_group_members_delete"
on public.customer_group_members
for delete
to authenticated
using (
  public.can_manage_customer_group_member(customer_group_id)
);
