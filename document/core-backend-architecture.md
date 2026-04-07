# Core Backend Architecture

SQL reference for the non-costing backend.

## Identity

```sql
create or replace function public.current_user_email()
returns text
language sql
stable
as $$
  select lower(trim(coalesce(auth.jwt() ->> 'email', '')))
$$;
```

## Roles

- internal: `superadmin`, `admin`, `staff`
- customer-side: `admin`, `negotiator`, `staff`

## Core Tables

### `public.memberships`

- `id`
- `tenant_id`
- `role`
- `is_active`
- `email`
- `created_at`
- `updated_at`

### `public.tenants`

- `id`
- `name`
- `slug`
- `is_active`
- `created_at`
- `updated_at`

### `public.customer_groups`

- `id`
- `tenant_id`
- `name`
- `is_active`
- `created_at`
- `updated_at`

### `public.customer_group_members`

- `id`
- `customer_group_id`
- `name`
- `email`
- `role`
- `is_active`
- `created_at`
- `updated_at`

## Helpers

```sql
create or replace function public.is_superadmin()
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.memberships m
    where lower(trim(m.email)) = public.current_user_email()
      and m.role = 'superadmin'
      and m.is_active = true
      and m.tenant_id is null
  )
$$;
```

```sql
create or replace function public.is_tenant_admin(p_tenant_id bigint)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.memberships m
    where lower(trim(m.email)) = public.current_user_email()
      and m.tenant_id = p_tenant_id
      and m.role = 'admin'
      and m.is_active = true
  )
$$;
```

```sql
create or replace function public.can_manage_membership(
  p_target_tenant_id bigint,
  p_target_role app_role
)
returns boolean
language sql
stable
as $$
  select
    public.is_superadmin()
    or (
      public.is_tenant_admin(p_target_tenant_id)
      and p_target_role in ('staff', 'viewer', 'customer')
    )
$$;
```

## RPCs

### Login

- `public.check_login_membership(p_email text, p_scope text)`
- `public.check_shop_login_access(p_email text, p_tenant_id bigint default null)`

### Bootstrap

- `public.get_app_bootstrap_context(p_email text default null, p_tenant_id bigint default null, p_membership_id bigint default null)`
- `public.get_shop_bootstrap_context(p_email text default null, p_tenant_id bigint default null, p_customer_group_member_id bigint default null)`

## RLS

```sql
create policy "members_can_view_tenants"
on public.tenants
for select
to authenticated
using (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = public.tenants.id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  )
);
```

```sql
create policy "memberships_select_own"
on public.memberships
for select
to authenticated
using (
  lower(trim(email)) = public.current_user_email()
);
```

```sql
create policy "memberships_select"
on public.memberships
for select
to authenticated
using (
  public.is_superadmin()
  or public.is_tenant_admin(tenant_id)
);
```

```sql
create policy "memberships_insert"
on public.memberships
for insert
to authenticated
with check (
  public.is_superadmin()
  or public.can_manage_membership(tenant_id, role)
);
```
