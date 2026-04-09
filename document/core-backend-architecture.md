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

## User Identification Model

Always identify the authenticated actor using both:

- `actor_type`
- `role`

Do not identify by role alone, because `admin` exists in both internal and customer-side models.

### Actor Types

- internal actor: membership row in `public.memberships`
- customer actor: customer member row in `public.customer_group_members`

### Source of Truth by Scope

- `platform` and `app` scopes:
  - source table: `public.memberships`
  - login RPC: `public.check_login_membership(p_email, p_scope)`
  - actor type: `membership`
- `shop` scope:
  - source table: `public.customer_group_members`
  - login RPC: `public.check_shop_login_access(p_email, p_tenant_id)`
  - actor type: `customer_group_member`

### Canonical Identity Rules

- `actor_type = membership` and `role = superadmin` => global internal superadmin
- `actor_type = membership` and `role in (admin, staff, viewer)` => tenant-scoped internal member
- `actor_type = customer_group_member` and `role in (admin, negotiator, staff)` => customer-side member

### Backend Implementation Rule

When writing RLS or RPC authorization:

- first decide actor type (`membership` vs `customer_group_member`)
- then apply role checks inside that actor type
- never mix customer-group role checks into `memberships` authorization
- never mix membership role checks into customer-group authorization

## Roles

- internal (`public.app_role`): `superadmin`, `admin`, `staff`, `viewer`
- customer-side (`public.customer_group_role`): `admin`, `negotiator`, `staff`

## Core Tables

### `public.memberships`

- `id`
- `tenant_id`
- `role`
- `is_active`
- `email`
- `created_at`
- `updated_at`

Integrity and normalization rules:

- emails are treated as normalized (`lower(trim(email))`) for auth checks
- unique identity key is `lower(trim(email)) + tenant_id` (`tenant_id` nullable for `superadmin`)
- `role = superadmin` must keep `tenant_id is null`
- `tenant_id` is a foreign key to `public.tenants(id)` (`on delete cascade`)
- write-time email normalization is enforced by trigger (`trg_memberships_normalize_email`)
- auth lookup index exists on `lower(trim(email))` (`memberships_email_idx`)
- normalized email + tenant uniqueness is enforced (`memberships_email_tenant_unique`)
- superadmin-per-email uniqueness is enforced with a partial unique index (`memberships_superadmin_email_unique`)
- superadmin tenant invariant is enforced by check constraint (`memberships_role_tenant_check`)

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

Integrity and normalization rules:

- unique per group: `(customer_group_id, lower(trim(email)))`
- write-time guard trigger prevents same email from being added to multiple customer groups in the same tenant

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
create or replace function public.can_update_membership_row(
  p_existing_tenant_id bigint,
  p_existing_role app_role
)
returns boolean
language sql
stable
as $$
  select
    public.is_superadmin()
    or (
      public.is_tenant_admin(p_existing_tenant_id)
      and p_existing_role in ('staff', 'viewer')
    )
$$;
```

```sql
create or replace function public.can_assign_membership_role(
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
      and p_target_role in ('staff', 'viewer')
    )
$$;
```

```sql
create or replace function public.can_customer_access_group(
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
    from public.customer_group_members cgm
    where cgm.customer_group_id = p_customer_group_id
      and lower(trim(cgm.email)) = public.current_user_email()
      and cgm.is_active = true
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

## Authorization Pattern For New Features

Use this checklist whenever you add backend features:

1. Pick actor type first:
   - internal flow => `memberships` helpers (`is_superadmin`, `is_tenant_admin`, `can_update_membership_row`, `can_assign_membership_role`)
   - customer flow => customer-group helpers (`can_manage_customer_group`, `can_manage_customer_group_member`, customer access helpers)
2. Write RLS with same-table helpers only:
   - internal tables should not depend on customer-group roles
   - customer tables should not depend on membership viewer/staff/admin roles unless explicitly intended
3. In RPCs, authorize before mutation:
   - normalize email (`lower(trim(...))`)
   - deny early if helper check fails
   - then perform `insert/update/delete`
4. Keep helper functions that read protected tables as `security definer` with `set search_path = public`.

## Security Definer Usage Rule

- Helper functions such as `can_customer_access_group` are predicates for RLS/RPC authorization paths.
- Avoid exposing them as general-purpose client APIs for business workflows.
- Keep their surface minimal and deterministic (no side effects, no writes).

## Customer Table RLS Coverage

Customer-side tables are protected separately from internal membership tables.

Covered policies include:

- `customer_groups_select/insert/update/delete`
- `customer_group_members_select/insert/update/delete`

Authorization is based on customer-group helpers (`can_manage_customer_group`, `can_manage_customer_group_member`) rather than `memberships` role checks.

Reference migration: `supabase/migrations/20260402113000_customer_groups_step2_rls.sql`.

## RLS

```sql
create policy "superadmin_can_manage_tenants"
on public.tenants
for all
to authenticated
using (public.is_superadmin())
with check (public.is_superadmin());
```

```sql
create policy "members_can_view_tenants"
on public.tenants
for select
to authenticated
using (
  public.is_superadmin()
  or exists (
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
  public.can_assign_membership_role(tenant_id, role)
);
```

```sql
create policy "memberships_update"
on public.memberships
for update
to authenticated
using (
  public.can_update_membership_row(tenant_id, role)
)
with check (
  public.can_assign_membership_role(tenant_id, role)
);
```

```sql
create policy "memberships_delete"
on public.memberships
for delete
to authenticated
using (
  public.can_update_membership_row(tenant_id, role)
);
```
