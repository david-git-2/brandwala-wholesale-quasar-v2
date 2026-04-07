# Access Design Blueprint

This document is the working blueprint for designing new database tables, modules, RLS policies, RPCs, and frontend access rules in this repo.

Use it when you want to add something like `products`, `categories`, `pricing_rules`, or any other feature that needs role-based access.

The goal is simple:

- keep the database as the source of truth
- keep the frontend permission model aligned with the backend
- make it easy for a developer or AI to follow the same pattern every time

## What This Repo Uses As Access Inputs

There are four main inputs to access decisions:

1. `scope`
2. `tenant`
3. `module`
4. `role`

If one of those is missing, permission checks should usually fail closed.

### Scope

Scopes are the entry context for the session:

- `platform`
- `app`
- `shop`

Scope decides which login path, dashboard, and role family the user is allowed to use.

### Tenant

Tenant is the ownership boundary for most business data.

Typical tenant-related tables:

- `public.tenants`
- `public.memberships`
- `public.tenant_modules`
- `public.customer_groups`
- `public.customer_group_members`

Most business tables should include `tenant_id` unless the data is truly system-wide.

### Module

Modules decide whether a tenant has a feature enabled.

Module examples already in the repo:

- `order_management`
- `shipment`
- `inventory`
- `vendor`
- `product_based_costing`
- `costing_file`
- `accounting`
- `invoice`

Module enablement is stored in:

- `public.modules`
- `public.tenant_modules`

The active module list is loaded during bootstrap and saved into the auth snapshot as `activeModuleKeys`.

### Role

There are two role systems:

- internal app roles in `public.memberships.role`
- customer-side roles in `public.customer_group_members.role`

Internal app roles:

- `superadmin`
- `admin`
- `staff`

Customer-side roles:

- `admin`
- `negotiator`
- `staff`

The app should not invent new roles in the UI. It should read them from the right table and then map them into the frontend access model when needed.

## How Login Resolves Role

### Platform and app login

Login uses:

- `public.check_login_membership(p_email, p_scope)`

This checks `public.memberships` and returns the best match for the current scope.

Expected scope mapping:

- `platform` -> `superadmin`
- `app` -> `admin`, `staff`

### Shop login

Shop login uses:

- `public.check_shop_login_access(p_email, p_tenant_id)`

This checks `public.customer_group_members` and returns the current customer-side role.

The shop bootstrap RPC is:

- `public.get_shop_bootstrap_context(...)`

That RPC returns the member, customer group, tenant, and the tenant’s active modules.

## How The Frontend Uses Role

After login, the auth store keeps the resolved access context.

Key fields:

- `authStore.scope`
- `authStore.member`
- `authStore.matchedRole`
- `authStore.tenantId`
- `authStore.customerGroupId`
- `authStore.activeModuleKeys`

Key frontend files:

- `web/src/modules/auth/composables/useOAuthLogin.ts`
- `web/src/modules/auth/stores/authStore.ts`
- `web/src/modules/auth/guards/accessGuard.ts`
- `web/src/modules/navigation/modulePermissions.ts`

The frontend should only be a mirror of the backend rules.
It can hide items and redirect users, but it should not be the only enforcement layer.

## The Default Design Pattern

When adding a new table or feature, use this order:

1. Decide who owns the data.
2. Decide which scope can access it.
3. Decide which tenant or customer group it belongs to.
4. Decide whether the feature depends on a module being enabled.
5. Decide which roles can read, create, update, or delete.
6. Design the schema.
7. Add indexes and constraints.
8. Enable RLS.
9. Add helper functions if the policy needs cross-table checks.
10. Make helper functions `security definer` if they must read protected tables.
11. Add RPCs when direct client writes would make RLS awkward.
12. Grant the RPCs the client needs.
13. Regenerate Supabase types.
14. Update the frontend stores, repositories, guards, and module permissions.

## Schema Checklist For A New Table

For a new business table like `products`, start by deciding which of these columns are needed:

- `id`
- `tenant_id`
- `name`
- `code` or `slug`
- `is_active`
- `is_system` if there are protected seed rows
- `created_at`
- `updated_at`

Add extra columns only if they are needed for the feature.

### Good defaults

- use `bigserial` consistently with the rest of the feature
- normalize text fields in triggers if casing matters
- add a uniqueness rule for tenant-scoped identifiers when needed
- add an `updated_at` trigger
- add a `check` constraint if a row must have a special shape

## Access Design Checklist

For each new table, answer these questions:

1. Should superadmin manage all rows?
2. Should tenant admin manage only rows in their tenant?
3. Should staff read-only access be allowed?
4. Should customer-side users ever see the rows?
5. Does access depend on module enablement?
6. Does access depend on the row being active?
7. Does access depend on ownership, creator, or workflow state?

If the answer is “yes” to any conditional rule, document it before writing SQL.

## RLS Pattern

Use RLS for the real data boundary.

Common patterns in this repo:

- direct table access for simple system tables
- helper-based RLS for tenant-aware checks
- RPC-based writes when policies depend on computed access

### Rule of thumb

- use RLS when the rule is about row visibility or row ownership
- use RPC when the rule needs multiple checks and the client should not assemble them itself

### Helper function pattern

Use a helper function when the policy needs to ask a question like:

- is this user a superadmin?
- is this user an admin for this tenant?
- is this tenant module enabled?
- does this customer group belong to the active tenant?

Keep helpers:

- small
- stable
- `search_path = public`
- `security definer` when they read protected tables

## RPC Pattern

Use RPCs when:

- the action is write-heavy
- the action needs multiple permission checks
- the action should return a complete bootstrap payload
- the action should avoid client-side policy assembly

Good RPC examples already in the repo:

- login and bootstrap RPCs
- tenant CRUD RPCs
- module helper RPCs
- vendor access setting RPCs

RPC rules:

- `security definer`
- `set search_path = public`
- validate access early
- return a shape the frontend can consume directly
- use a CTE if Postgres complains about ambiguous columns

## Module Pattern

If a feature should only exist for some tenants, treat it as a module.

Typical module flow:

1. add the module key to `public.modules`
2. assign the module to tenants through `public.tenant_modules`
3. load the enabled module keys at bootstrap
4. hide the module in the frontend if it is not enabled
5. enforce module checks in RLS or RPC where needed

This means a feature can be:

- schema-present but module-disabled
- visible in the backend but hidden in the frontend
- allowed for some roles but not others

## Tenant Pattern

Most features should follow tenant ownership.

If a table belongs to one tenant, make the rule explicit:

- include `tenant_id`
- index `tenant_id`
- make the insert/update/delete rules check the tenant
- keep tenant reads scoped to the current actor

If the feature is system-wide, say that clearly and explain why it is not tenant-scoped.

## Example: New `products` Table

Suppose we want to create a new `public.products` table and allow:

- read access to all relevant authenticated users
- write access to `superadmin` and `admin`
- optional staff read access
- optional customer access if the feature is exposed in shop scope

### Step 1: Decide the ownership

Ask first:

- is the product catalog global?
- is it tenant-specific?
- do different tenants need different products?

If it is tenant-specific, use `tenant_id`.
If it is shared but configurable per tenant, still keep tenant ownership explicit somewhere.

### Step 2: Decide the module

If products are part of a feature area, add a module key like:

- `product_catalog`

Then:

- add it to `public.modules`
- turn it on per tenant through `public.tenant_modules`
- use `activeModuleKeys` in the frontend

### Step 3: Decide the access rules

Example rule set:

- `superadmin`: full access
- `admin`: full access inside own tenant
- `staff`: read-only
- `customer`: read-only only if exposed in shop scope and module is enabled

### Step 4: Model the table

A typical table might include:

- `id`
- `tenant_id`
- `name`
- `code`
- `description`
- `is_active`
- `created_at`
- `updated_at`

Optional additions:

- `is_system`
- `sort_order`
- `metadata`

### Step 5: Write the policies

For a table like `products`, the policies usually follow this shape:

- `select`: allow the roles that may read the records, but still verify tenant, scope, and module rules
- `insert`: allow only the roles that can create products
- `update`: allow only the roles that can edit products
- `delete`: allow only the roles that can remove products

If the policy depends on module enablement, check module state in the policy or helper.

If the policy depends on tenant admin status, use the existing helper pattern.

### Step 6: Decide if RPCs are needed

If product creation needs extra checks, prefer an RPC instead of a direct insert.

Examples of reasons to use an RPC:

- code must be normalized
- tenant checks need to happen in one place
- the write should return a fully shaped row
- the client should not be allowed to fake access conditions

### Step 7: Update the frontend

If the feature has a page, follow the normal flow:

- page
- store
- service
- repository

Then update:

- route guards
- module permissions
- auth snapshot hydration
- UI visibility

## Example Access Matrix For `products`

This is an example matrix you can adapt.

| Role                  | Select         | Insert | Update | Delete |
| --------------------- | -------------- | ------ | ------ | ------ |
| `superadmin`          | yes            | yes    | yes    | yes    |
| `admin`               | yes            | yes    | yes    | yes    |
| `staff`               | yes            | no     | no     | no     |
| `customer admin`      | yes if exposed | no     | no     | no     |
| `customer negotiator` | yes if exposed | no     | no     | no     |
| `customer staff`      | yes if exposed | no     | no     | no     |

If the feature is internal-only, drop the customer-side rows.
If the feature should be read-only for everyone, keep `select` broad and restrict writes.

## What To Give An AI

If you want an AI to design a new feature correctly, give it these inputs:

- table name
- whether it is tenant-scoped or global
- which module it belongs to
- which scope can reach it
- which roles can read, create, update, and delete
- whether customer-side users should see it
- whether the frontend should hide it when the module is disabled
- whether writes should use RPCs

Suggested prompt:

```text
Design a new table and access model using the repo’s current pattern.

Context:
- internal roles come from public.memberships / public.app_role
- customer roles come from public.customer_group_members / public.customer_group_role
- tenant-level module enablement comes from public.tenant_modules
- login and bootstrap access should be resolved through security definer RPCs
- RLS must enforce the real permissions

Feature:
- table name: public.products
- scope: app
- tenant-owned: yes
- module key: product_catalog
- read access: superadmin, admin, staff
- write access: superadmin and admin
- customer access: none

Tell me:
1. the schema
2. the RLS policies
3. the helper functions
4. any RPCs needed
5. the frontend files that should be updated
```

## Quick Mental Model

1. Login resolves the actor from the correct membership table.
2. Bootstrap loads the tenant, module, and context needed by the UI.
3. The frontend uses that context to hide or show routes.
4. RLS and RPCs enforce the actual permission boundary.
5. New features should follow the same shape so the codebase stays consistent.

## Files To Read First

- [`README.md`](/Users/david/Desktop/projects/group/brandwala-wholesale-quasar-v2/README.md)
- [`document/costing-file-rls.md`](/Users/david/Desktop/projects/group/brandwala-wholesale-quasar-v2/document/costing-file-rls.md)
- [`web/src/modules/auth/composables/useOAuthLogin.ts`](/Users/david/Desktop/projects/group/brandwala-wholesale-quasar-v2/web/src/modules/auth/composables/useOAuthLogin.ts)
- [`web/src/modules/auth/stores/authStore.ts`](/Users/david/Desktop/projects/group/brandwala-wholesale-quasar-v2/web/src/modules/auth/stores/authStore.ts)
- [`web/src/modules/auth/guards/accessGuard.ts`](/Users/david/Desktop/projects/group/brandwala-wholesale-quasar-v2/web/src/modules/auth/guards/accessGuard.ts)
- [`web/src/modules/navigation/modulePermissions.ts`](/Users/david/Desktop/projects/group/brandwala-wholesale-quasar-v2/web/src/modules/navigation/modulePermissions.ts)
- [`web/src/modules/navigation/moduleRegistry.ts`](/Users/david/Desktop/projects/group/brandwala-wholesale-quasar-v2/web/src/modules/navigation/moduleRegistry.ts)
- [`web/src/modules/tenant/README.md`](/Users/david/Desktop/projects/group/brandwala-wholesale-quasar-v2/web/src/modules/tenant/README.md)
- [`supabase/migrations/20260331120000_initial_schema.sql`](/Users/david/Desktop/projects/group/brandwala-wholesale-quasar-v2/supabase/migrations/20260331120000_initial_schema.sql)
- [`supabase/migrations/20260331121000_login_access_rpc.sql`](/Users/david/Desktop/projects/group/brandwala-wholesale-quasar-v2/supabase/migrations/20260331121000_login_access_rpc.sql)
- [`supabase/migrations/20260331124000_login_membership_member_payload.sql`](/Users/david/Desktop/projects/group/brandwala-wholesale-quasar-v2/supabase/migrations/20260331124000_login_membership_member_payload.sql)
- [`supabase/migrations/20260402110000_customer_groups_step1.sql`](/Users/david/Desktop/projects/group/brandwala-wholesale-quasar-v2/supabase/migrations/20260402110000_customer_groups_step1.sql)
- [`supabase/migrations/20260402120000_shop_login_access_rpc.sql`](/Users/david/Desktop/projects/group/brandwala-wholesale-quasar-v2/supabase/migrations/20260402120000_shop_login_access_rpc.sql)
- [`supabase/migrations/20260402133000_login_bootstrap_step5.sql`](/Users/david/Desktop/projects/group/brandwala-wholesale-quasar-v2/supabase/migrations/20260402133000_login_bootstrap_step5.sql)
- [`supabase/migrations/20260406180000_markets_module.sql`](/Users/david/Desktop/projects/group/brandwala-wholesale-quasar-v2/supabase/migrations/20260406180000_markets_module.sql)
- [`supabase/migrations/20260406213000_vendor_module_schema_permissions.sql`](/Users/david/Desktop/projects/group/brandwala-wholesale-quasar-v2/supabase/migrations/20260406213000_vendor_module_schema_permissions.sql)
