# Step-by-Step Implementation Guide

This guide turns the master plan into an implementation sequence we can follow safely.

The working style for this project should be:

1. implement one step
2. verify that step
3. move to the next step

Use this file as the execution checklist.

Use `MASTER_PLAN.md` as the product source of truth.

Use `LOGIN_NAV_PERMISSION_FLOW.md` as the access-flow reference.

## Guiding Rule

Keep this rule throughout implementation:

- database controls which modules exist for a tenant
- code controls what each role can do inside those modules

## Recommended Order

### Step 1. Create Customer Access Tables

Goal:

Add the customer-side data model required by the master plan.

Scope:

- create `customer_groups`
- create `customer_group_members`
- add required indexes
- add basic constraints
- add `updated_at` triggers if needed

Important rules from the master plan:

- `customer_groups` belongs to one tenant
- `customer_group_members` belongs to one customer group
- role must support:
  - `admin`
  - `negotiator`
  - `staff`
- email must be unique inside the same customer group

Do not do yet:

- login RPC changes
- frontend changes
- permission bootstrap

Verify:

- tables exist
- constraints are correct
- uniqueness rule works
- tenant relationship works

### Step 2. Add Customer Access RLS and Helper Functions

Goal:

Protect the new customer tables and define access rules.

Scope:

- enable RLS on `customer_groups`
- enable RLS on `customer_group_members`
- add helper functions needed for tenant admin checks
- add read/write policies for:
  - superadmin
  - tenant admin

Expected behavior:

- superadmin can manage all customer groups and members
- tenant admin can manage customer groups and members only inside their tenant
- staff should not manage customer access records unless the plan later says so

Do not do yet:

- shop login RPC
- frontend integration

Verify:

- tenant admin can access only their own tenant data
- cross-tenant access is blocked
- superadmin access still works

### Step 3. Implement `/shop` Login Check

Goal:

Make shop login follow the master plan instead of internal membership logic.

Scope:

- create or update login RPC for `/shop`
- validate against `customer_group_members`
- resolve tenant context through `customer_groups`
- return the customer actor payload needed by frontend

Expected behavior:

- `/platform` still checks `memberships`
- `/app` still checks `memberships`
- `/shop` checks `customer_group_members`

Important rule:

- internal tenant users cannot use `/shop` unless they also exist as a customer-group member

Do not do yet:

- navigation generation
- module-aware route guards

Verify:

- valid customer member can log in to `/shop`
- invalid email cannot log in
- internal membership alone does not grant `/shop` access

### Step 4. Add Tenant Module Management Backend

Goal:

Make `tenant_modules` usable as the source of tenant feature enablement.

Scope:

- add any missing RPCs for tenant modules
- support:
  - list tenant modules
  - assign module to tenant
  - update active state
  - remove module from tenant if needed

Expected behavior:

- superadmin manages tenant module assignments
- tenant users can read only what they are allowed to read

Do not do yet:

- role-action DB permissions
- dynamic frontend navigation

Verify:

- superadmin can assign modules to a tenant
- enabled/disabled state is returned correctly
- duplicate tenant/module assignment is blocked

### Step 5. Create Post-Login Bootstrap RPCs

Goal:

Reduce frontend guesswork by returning session-ready context after login.

Scope:

- create bootstrap RPC for `/app`
- create bootstrap RPC for `/shop`
- return:
  - actor/member info
  - tenant info
  - active module keys
  - any context required for shell rendering

Expected behavior:

- frontend does not need to manually stitch together many calls after login

Do not do yet:

- full frontend shell rewrite

Verify:

- bootstrap returns correct tenant
- bootstrap returns only active tenant modules
- app and shop payloads match their own scope rules

### Step 6. Update Frontend Auth Store for Scope Context

Goal:

Store enough actor/session context for the shell and guards.

Scope:

- extend auth/session store shape if needed
- store:
  - scope
  - role
  - tenant id
  - membership id or customer-group-member id
  - customer group id for `/shop`

Expected behavior:

- each scope has the minimum stable context needed after login

Do not do yet:

- dynamic nav rendering

Verify:

- login persists the right actor context
- logout clears it
- page refresh preserves valid context

### Step 7. Implement Module Registry in Frontend Code

Goal:

Define one frontend source of truth for possible navigation items and module routes.

Scope:

- create a module navigation registry
- map each module key to:
  - label
  - route
  - icon
  - scope
  - required action if needed

Expected behavior:

- layouts no longer need hardcoded business-module links

Do not do yet:

- final dynamic filtering in layouts

Verify:

- every planned module has a registry entry
- route mapping is consistent

### Step 8. Implement Permission Resolution in Code

Goal:

Apply the chosen rule:

- DB decides whether module exists for tenant
- code decides what role can do inside module

Scope:

- add code-based permission map for roles
- calculate effective permissions using:
  - scope
  - role
  - active tenant modules

Expected behavior:

- module access requires both:
  - module enabled
  - role allowed

Do not do yet:

- per-action database-driven permission system

Verify:

- disabled module never appears as usable
- enabled module is still blocked if role is not allowed

### Step 9. Generate Navigation From Permissions

Goal:

Replace hardcoded layout navigation with generated navigation.

Scope:

- create nav composable/store
- build visible menu items from:
  - scope
  - active module keys
  - role permission map
- wire layouts to that generated list

Expected behavior:

- `/platform`, `/app`, and `/shop` each show only allowed links

Verify:

- changing tenant modules changes visible nav
- changing role changes visible nav
- layouts render correctly with no hardcoded business-module assumptions

### Step 10. Upgrade Route Guards

Goal:

Protect routes using both auth and module access.

Scope:

- keep login/scope checks
- add module-aware checks
- block access when:
  - module disabled
  - role not allowed

Expected behavior:

- hidden nav item cannot still be opened directly by URL

Verify:

- direct route access is blocked when permission fails
- valid route access still works

### Step 11. Build Customer Group Admin UI

Goal:

Expose the new customer access model in `/app`.

Scope:

- customer group listing
- create/edit customer group
- customer group member listing
- create/edit/deactivate customer group member

Expected behavior:

- tenant admin can manage customer-side access from internal app area

Verify:

- tenant admin sees only their tenant’s customer groups
- create/update flows work
- customer roles save correctly

### Step 12. Finish Shop Area Integration

Goal:

Make `/shop` fully use customer-group login and permission context.

Scope:

- update shop login flow
- update shop shell
- update shop guards
- ensure shop routes use customer actor context, not internal membership logic

Verify:

- shop login follows customer-group access only
- shop nav respects enabled modules
- customer roles behave correctly

## Verification Style For Every Step

For each step, verification should include:

- schema check
- permission check
- negative case check
- regression check on earlier scopes

In plain language:

- confirm the new thing works
- confirm forbidden access is blocked
- confirm older flows did not break

## Suggested Working Loop

Use this exact cycle:

1. implement step N
2. verify step N
3. summarize what changed
4. wait for approval
5. move to step N+1

## First Step To Start With

Start with Step 1.

Reason:

- it is required by the master plan
- it unlocks proper `/shop` login
- it has low frontend impact
- it gives us a clean backend base for later steps
