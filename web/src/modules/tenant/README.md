# Tenant Module

This module is the platform tenant admin area.

It follows the same `page -> store -> service -> repository` pattern as the example module, but all database mutations now go through Supabase RPCs so RLS stays predictable.

## Current Table Structure

### `public.tenants`

| Column | Type | Notes |
| --- | --- | --- |
| `id` | `bigserial` | Primary key |
| `name` | `text` | Required |
| `slug` | `text` | Required, unique |
| `is_active` | `boolean` | Defaults to `true` |
| `created_at` | `timestamptz` | Defaults to `now()` |
| `updated_at` | `timestamptz` | Defaults to `now()` |

### `public.memberships`

| Column | Type | Notes |
| --- | --- | --- |
| `id` | `bigserial` | Primary key |
| `profile_id` | `bigint` | Legacy relation, still present in the base schema |
| `tenant_id` | `bigint` | Null for `superadmin` |
| `role` | `app_role` | `superadmin`, `admin`, `staff`, `viewer`, `customer` |
| `is_active` | `boolean` | Defaults to `true` |
| `created_at` | `timestamptz` | Defaults to `now()` |
| `updated_at` | `timestamptz` | Defaults to `now()` |

Current access checks rely on `memberships.email` through the later migration history, not on the original `profiles` join.

### `public.profiles`

`profiles` still exists in the schema, but the current login flow does not depend on it for tenant access.

## Login Flow

1. User clicks Google login on one of these routes:
   - `/auth/platform/login`
   - `/auth/add/login`
   - `/auth/shop/login`
2. Supabase returns to:
   - `/auth/callback?scope=platform`
   - `/auth/callback?scope=app`
   - `/auth/callback?scope=shop`
3. The callback page reads the Supabase session email.
4. The callback calls `check_login_membership(p_email, p_scope)`.
5. If a matching membership row exists:
   - the auth store saves the user snapshot and member snapshot
   - the user is redirected to the matching dashboard
     - `platform/dashboard`
     - `app/dashboard`
     - `shop/dashboard`
6. If no matching membership row exists:
   - the session is cleared
   - the user goes back to the matching login page with an error message

## Tenant Data Flow

### Read

`TenantPage.vue` loads tenants through:

1. `tenantStore.fetchTenants()`
2. `tenantService.listTenants()`
3. `tenantRepository.listTenants()`
4. `supabase.rpc('list_tenants_for_superadmin')`

### Create

`tenantStore.createTenant()` now goes through:

1. `tenantService.createTenant()`
2. `tenantRepository.createTenant()`
3. `supabase.rpc('create_tenant_for_superadmin')`

### Update

`tenantStore.updateTenant()` now goes through:

1. `tenantService.updateTenant()`
2. `tenantRepository.updateTenant()`
3. `supabase.rpc('update_tenant_for_superadmin')`

### Delete

`tenantStore.deleteTenant()` now goes through:

1. `tenantService.deleteTenant()`
2. `tenantRepository.deleteTenant()`
3. `supabase.rpc('delete_tenant_for_superadmin')`

## RLS Pattern To Follow Next Time

When you add a new module, follow this order:

1. Define the table first in a migration.
2. Add only the indexes you know you need.
3. Turn on RLS for the table.
4. Add helper functions only if the policy needs cross-table checks.
5. If a helper must read an RLS-protected table, make it `security definer`.
6. For write operations, prefer RPCs over direct client inserts/updates/deletes when the policy depends on computed access.
7. Use `returning *` or a CTE when the function shape is simple.
8. Avoid naming collisions between function output columns and table columns.
9. Regenerate Supabase types after every schema change.

## RPC Pattern To Follow Next Time

For simple CRUD RPCs:

1. Use `security definer`.
2. Set `search_path = public`.
3. Guard access early with `public.is_superadmin()` or the right helper.
4. Use SQL functions if the logic is a single insert/update/delete.
5. Use a CTE for DML if Postgres starts complaining about ambiguous output column names.

## Files To Look At First

- [`web/src/modules/tenant/repositories/tenantRepository.ts`](/Users/david/Desktop/projects/group/brandwala-wholesale-quasar-v2/web/src/modules/tenant/repositories/tenantRepository.ts)
- [`web/src/modules/tenant/services/tenantService.ts`](/Users/david/Desktop/projects/group/brandwala-wholesale-quasar-v2/web/src/modules/tenant/services/tenantService.ts)
- [`web/src/modules/tenant/stores/tenantStore.ts`](/Users/david/Desktop/projects/group/brandwala-wholesale-quasar-v2/web/src/modules/tenant/stores/tenantStore.ts)
- [`web/src/modules/auth/composables/useOAuthLogin.ts`](/Users/david/Desktop/projects/group/brandwala-wholesale-quasar-v2/web/src/modules/auth/composables/useOAuthLogin.ts)
- [`supabase/migrations/20260331120000_initial_schema.sql`](/Users/david/Desktop/projects/group/brandwala-wholesale-quasar-v2/supabase/migrations/20260331120000_initial_schema.sql)
- [`supabase/migrations/20260331125000_membership_rls_definer.sql`](/Users/david/Desktop/projects/group/brandwala-wholesale-quasar-v2/supabase/migrations/20260331125000_membership_rls_definer.sql)
- [`supabase/migrations/20260331125500_tenant_list_rpc.sql`](/Users/david/Desktop/projects/group/brandwala-wholesale-quasar-v2/supabase/migrations/20260331125500_tenant_list_rpc.sql)
- [`supabase/migrations/20260331130500_redefine_create_tenant_rpc.sql`](/Users/david/Desktop/projects/group/brandwala-wholesale-quasar-v2/supabase/migrations/20260331130500_redefine_create_tenant_rpc.sql)
- [`supabase/migrations/20260331131000_tenant_update_delete_rpc.sql`](/Users/david/Desktop/projects/group/brandwala-wholesale-quasar-v2/supabase/migrations/20260331131000_tenant_update_delete_rpc.sql)
