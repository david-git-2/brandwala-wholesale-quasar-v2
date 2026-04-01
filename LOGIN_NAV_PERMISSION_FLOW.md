# Login, Navigation, and Permission Flow

This document refines the high-level direction in the master plan and defines the intended access flow for implementation.

## Why This Is Separate

Keep `MASTER_PLAN.md` as the product and architecture source of truth.

Use this file as the implementation context for:

- login flow
- post-login data fetch flow
- permission resolution
- auto-generated navigation

This separation is better because the master plan stays stable and readable, while this document can be updated as auth and module behavior become more detailed.

## Core Rule

Use this model:

- database controls which modules exist for a tenant
- code controls what each role can do inside those modules

In practice:

- `tenant_modules` decides whether a module is enabled for a tenant
- frontend/backend code decides what `superadmin`, `admin`, `staff`, and customer-side roles can do within that enabled module

## Scope Model

The app has 3 access scopes:

- `/platform`
- `/app`
- `/shop`

All scopes use the same Google OAuth mechanism.

What changes by scope is:

- which table is checked after login
- which roles are valid
- which context is loaded
- which routes and modules are visible

## Login Flow

### 1. User Enters a Scope

The user starts from one of these areas:

- `/platform` for superadmin
- `/app` for tenant internal users
- `/shop` for customer-side users

### 2. User Signs In With Google

Supabase handles Google OAuth.

### 3. Callback Reads the Authenticated Email

After OAuth returns, the callback page reads the Supabase session and gets the user email.

### 4. Backend Checks Access by Scope

#### `/platform`

Check `memberships`.

Valid match:

- active membership
- role = `superadmin`
- `tenant_id` is `null`

#### `/app`

Check `memberships`.

Valid match:

- active membership
- role = `admin` or `staff`
- membership belongs to the tenant

#### `/shop`

Check `customer_group_members`.

Valid match:

- active customer-group member
- member belongs to a customer group under the tenant
- member role is a valid customer-side role

Important rule:

- internal tenant members must not enter `/shop` unless they also exist in `customer_group_members` for that tenant

### 5. Failed Login Handling

If no valid match is found:

- clear session
- clear local auth/access state
- redirect back to that scope's login page

### 6. Successful Login Handling

If a valid match is found, save the minimum actor context needed for the session.

For `/platform`:

- auth user
- scope
- role

For `/app`:

- auth user
- scope
- role
- tenant id
- membership id

For `/shop`:

- auth user
- scope
- tenant id
- customer group id
- customer-group member id
- customer-side role

## Post-Login Fetch Flow

After login succeeds, fetch the context needed to drive the UI.

### `/platform`

Fetch:

- platform actor context
- platform navigation items

### `/app`

Fetch:

- tenant context
- active tenant modules from `tenant_modules`
- any tenant-specific bootstrap data needed by the shell

### `/shop`

Fetch:

- tenant context
- customer group context
- active tenant modules from `tenant_modules`
- any shop bootstrap data needed by the shell

## Permission Resolution

Permissions should be resolved in 2 steps.

### Step 1: Tenant Module Enablement

Read `tenant_modules`.

A module is available only if:

- a matching row exists for the tenant
- `is_active = true`

This controls tenant-level feature access and feature visibility.

### Step 2: Role Ability

Once a module is enabled for the tenant, application code decides what each role can do inside that module.

Example:

- tenant has `inventory`
- `admin` can manage inventory
- `staff` can only view inventory

This means effective permission is:

`module enabled for tenant` AND `role allowed to perform the action`

## Auto-Generated Navigation

Navigation should not be hardcoded per layout.

Instead, generate it from:

1. current scope
2. current actor role
3. current tenant context
4. active module keys from `tenant_modules`
5. code-defined role rules

### Recommended Navigation Model

Keep a frontend registry of all possible navigation entries.

Each registry item should define:

- `moduleKey`
- `label`
- `icon`
- `route`
- `scopes`
- optional required action such as `view`

Then build navigation like this:

1. load active module keys for the tenant
2. filter registry items by current scope
3. remove items whose module is not enabled
4. remove items whose role is not allowed
5. render the remaining items in the drawer/menu

## Route Guard Rule

A route should be accessible only if all of these pass:

- user is logged in
- current scope matches the area
- actor has a valid role for the route
- required module is enabled for the tenant

So route access becomes:

`authenticated` AND `scope valid` AND `role allowed` AND `module enabled`

## Data Source Summary

Use these sources:

- `memberships` for `/platform`
- `memberships` for `/app`
- `customer_group_members` for `/shop`
- `tenant_modules` for tenant-level module enablement
- application code for role-to-action permissions inside enabled modules

## Recommended Implementation Order

1. finalize `customer_groups` and `customer_group_members`
2. keep shared Google OAuth for all scopes
3. implement scope-aware login checks
4. implement post-login bootstrap fetch
5. load active tenant modules
6. resolve permissions in code
7. generate navigation from those permissions
8. update route guards to check module access as well as role

## One-Line Flow

`Google login -> scope-based access check -> save actor context -> fetch tenant modules -> apply role permissions in code -> generate navigation -> guard routes`
