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

### Step 1. Align Tenant Schema With The Master Plan

Goal:

Bring the live `tenants` table up to the fields the master plan already expects.

Scope:

- add missing tenant fields:
  - `public_domain`
  - `created_by` if we want audit ownership now
- make `public_domain` globally unique when present
- regenerate Supabase types
- update tenant TS types and repository payloads
- update superadmin tenant create/edit UI to expose the new field(s)

Important rules:

- `slug` stays unique
- `public_domain` should be globally unique
- tenant identity for customer entry must be resolvable from URL
- do not break existing tenant CRUD

Do not do yet:

- login flow rewrite
- route changes
- tenant selector behavior

Verify:

- migration runs cleanly
- old tenants remain readable
- create and edit tenant still work
- `public_domain` uniqueness is enforced

### Step 2. Define Tenant Resolution Strategy In Routing

Goal:

Make tenant context resolvable from URL before login for customer flows, and selectable after login for internal admin flows.

Scope:

- choose and document the concrete route model
- support tenant-aware customer entry using one of these URL patterns:
  - `/:tenantSlug/shop`
  - `/shop/:tenantSlug`
  - domain-mapped `public_domain`
- decide how internal admin tenant switching will work after `/app` login
- add route params or resolver helpers needed by frontend

Expected behavior:

- customer entry URL always identifies one tenant before login
- admin can choose between multiple tenants after login
- tenant context is explicit, not guessed from "first membership"

Do not do yet:

- final login implementation
- data migration for custom domains
- shell redesign

Verify:

- route design covers:
  - single-tenant admin
  - multi-tenant admin
  - single-tenant customer
  - multi-tenant customer
- no flow depends on ambiguous tenant lookup by email alone

### Step 3. Seed The Master Module Catalog

Goal:

Make sure the base `modules` table is populated from the module list in the master plan.

Scope:

- create a repeatable seed for `public.modules`
- seed the MVP module set from `MASTER_PLAN.md`, including:
  - order management
  - shipment
  - inventory
  - shop costing file
  - costing file
  - accounting
  - invoice
- define and lock stable `key` values for each seeded module
- make the seed idempotent so it can be safely rerun
- document how seeds should be applied in local/dev environments

Recommended seeded keys:

- `order_management` -> `Order Management`
- `shipment` -> `Shipment`
- `inventory` -> `Inventory`
- `shop_costing_file` -> `Shop Costing File`
- `costing_file` -> `Costing File`
- `accounting` -> `Accounting`
- `invoice` -> `Invoice`

Important rule:

- these seeded keys should become the shared contract across:
  - `public.modules`
  - `public.tenant_modules.module_key`
  - frontend module registry
  - route/module guard logic

Expected behavior:

- fresh environments get the expected module catalog automatically
- module keys are stable enough to use in tenant-module records and frontend registry code
- rerunning the seed does not create duplicates

Do not do yet:

- tenant-specific module assignment
- permission map implementation
- dynamic navigation

Verify:

- all master-plan MVP modules exist in `public.modules`
- each module has the expected `key`, `name`, and active state
- seeded keys match the frontend module registry contract
- rerunning the seed does not duplicate rows

### Step 4. Add Superadmin Module Management UI

Goal:

Expose the module catalog clearly in the superadmin area so modules can be viewed and maintained.

Scope:

- review and complete the platform modules page in `/platform/modules`
- show seeded modules in the UI
- support the required admin actions for module records:
  - list
  - create
  - edit
  - activate/deactivate
- make sure the page uses the final seeded module keys and labels
- align any create/edit dialogs with the module schema
- make sure duplicate keys and malformed keys are blocked clearly in UI validation

Expected behavior:

- superadmin can see the full module catalog
- seeded modules are visible immediately after setup
- module maintenance is possible without direct DB edits

Do not do yet:

- tenant-module assignment UX on this step unless already tightly coupled
- dynamic app/shop nav rollout

Verify:

- module list loads correctly
- seeded modules render with the right names
- create/edit/active-state actions work
- invalid duplicate keys are blocked
- edits do not break seeded keys already referenced by registry and tenant-module records

### Step 5. Add Backend Tenant Lookup Helpers

Goal:

Resolve a tenant from slug or public URL before customer login and bootstrap.

Scope:

- add RPC/helper to find a tenant by slug
- add RPC/helper to find a tenant by `public_domain`
- return only active/usable tenant data needed by auth flow
- keep responses small and safe for pre-login use

Expected behavior:

- frontend can resolve tenant context before Google login
- tenant resolution works whether entry used slug path or mapped public domain
- bad slug/domain fails cleanly

Important rule:

- customer login must never depend on "pick the first tenant for this email"

Do not do yet:

- auth store rewrite
- customer dashboard work

Verify:

- valid slug returns the right tenant
- unknown slug/domain returns no tenant
- inactive tenant behavior is defined and tested

### Step 6. Fix `/shop` Login To Be Tenant-Scoped

Goal:

Make customer login follow the master plan by requiring tenant context during login.

Scope:

- update login flow so `/shop` passes resolved tenant id into:
  - `check_shop_login_access`
  - `get_shop_bootstrap_context`
- ensure customer access is checked through `customer_group_members`
- ensure internal membership alone never grants `/shop`
- define failed-login behavior for wrong-tenant URLs

Expected behavior:

- a customer who belongs to multiple tenants can log in through the correct tenant URL
- the same email on another tenant does not accidentally log into the wrong shop
- customer actor session contains tenant and customer-group context

Do not do yet:

- customer tenant selector
- public domain DNS automation

Verify:

- correct tenant URL + valid member succeeds
- wrong tenant URL + same email fails cleanly
- customer with memberships in several tenants lands in the intended tenant

### Step 7. Replace "First Membership Wins" For `/app`

Goal:

Make internal app login safe for admins who belong to multiple tenants.

Scope:

- stop treating `/app` login as a single-tenant login
- let auth save the internal actor identity separately from selected tenant context
- decide whether post-login goes to:
  - a tenant selector page
  - or a tenant list page that acts as selector
- ensure admin can re-enter another tenant without logging out

Expected behavior:

- one admin email can access multiple tenants
- selected tenant is explicit in state
- tenant-specific bootstrap happens after tenant selection, not before

Do not do yet:

- dynamic module nav
- per-tenant deep-link restoration unless needed

Verify:

- admin with one tenant goes straight in or can be auto-selected by rule
- admin with multiple tenants must explicitly choose
- switching tenant updates active context safely

### Step 8. Add Selected-Tenant State To The Frontend Store

Goal:

Store tenant selection separately so the app can use it consistently across pages and future modules.

Scope:

- extend tenant store or add a dedicated workspace/session store
- persist:
  - available admin tenants
  - selected tenant id
  - selected tenant slug
- expose actions such as:
  - set selected tenant
  - clear selected tenant
  - hydrate selected tenant from auth/bootstrap
- update pages to read selected tenant from one place

Expected behavior:

- tenant-specific queries no longer depend on route-only assumptions
- later module pages can reuse the same selected tenant context
- store is ready for a tenant switcher in the shell

Do not do yet:

- broad shell redesign
- route guard rewrite

Verify:

- refresh preserves selected tenant when valid
- logout clears selected tenant
- switching tenant updates dependent data loads

### Step 9. Build Admin Tenant Selector UX

Goal:

Give internal admins a clear way to choose and switch tenants.

Scope:

- add tenant selection page or dialog for `/app`
- add a tenant switcher in the app shell/header
- show tenant name and slug in the selector
- on selection:
  - save selected tenant in store
  - fetch tenant-scoped bootstrap/module data
  - route into the chosen tenant workspace

Expected behavior:

- admins can move between tenants without confusion
- tenant selection is visible and intentional
- future features can rely on selected tenant context

Do not do yet:

- full design polish
- customer-facing selector

Verify:

- selector shows only admin-accessible tenants
- choosing another tenant updates the app context
- no stale data remains after switching

### Step 10. Build Customer Tenant Entry UX

Goal:

Make customer entry clearly tenant-specific before login.

Scope:

- add tenant-branded customer entry page based on slug/domain
- show tenant name and public URL branding if available
- block entry when tenant is unknown or inactive
- use the resolved tenant when starting Google OAuth

Expected behavior:

- customers do not need a tenant selector
- customer always knows which tenant shop they are entering
- URL drives the tenant context

Do not do yet:

- marketing site features
- custom theme per tenant unless already planned

Verify:

- `/shop/<tenant>` or equivalent resolves tenant before login
- wrong slug shows friendly error
- correct tenant branding appears before sign-in

### Step 11. Rework Bootstrap Flow Around Explicit Tenant Context

Goal:

Return session-ready context only after tenant context is explicit.

Scope:

- review and adjust bootstrap RPC usage for both `/app` and `/shop`
- `/app` bootstrap should use selected tenant and actor membership
- `/shop` bootstrap should use resolved tenant and customer-group member
- return:
  - actor/member info
  - tenant info
  - active module keys
  - customer group context where needed

Expected behavior:

- frontend does not guess tenant context from email ordering
- all shells render from explicit tenant-aware bootstrap data

Do not do yet:

- full frontend shell rewrite

Verify:

- app bootstrap returns selected tenant, not arbitrary tenant
- shop bootstrap returns route-resolved tenant, not arbitrary tenant
- active modules are tenant-correct

### Step 12. Update Frontend Auth Store For Explicit Session Context

Goal:

Store enough actor/session context for the shell and guards.

Scope:

- extend auth/session store shape if needed
- store:
  - scope
  - role
  - actor id
  - actor type
  - available admin tenants if needed
  - selected tenant id
  - selected tenant slug
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

### Step 13. Add Tenant Module Management Backend Review

Goal:

Make sure `tenant_modules` is ready to drive tenant-aware app and shop shells.

Scope:

- review current tenant module RPCs
- confirm bootstrap returns active module keys correctly
- confirm module enablement can be read for both internal app and shop flows
- fill any missing gaps in CRUD or read APIs

Expected behavior:

- tenant-level feature enablement stays in DB
- both app and shop can trust bootstrap module keys
- tenant-module assignment only uses keys that exist in the seeded module catalog

Do not do yet:

- role-action DB permissions
- final nav generation

Verify:

- enabled/disabled state is correct
- duplicate tenant/module assignment is blocked
- bootstrap exposes the right active modules per tenant
- unknown module keys cannot be assigned to tenants

### Step 14. Implement Module Registry In Frontend Code

Goal:

Define one frontend source of truth for possible navigation items and module routes.

Scope:

- create a module navigation registry
- map each module key to:
  - label
  - route
  - icon
  - scopes
  - required action if needed
- align registry keys exactly with the seeded module catalog

Recommended registry key set:

- `order_management`
- `shipment`
- `inventory`
- `shop_costing_file`
- `costing_file`
- `accounting`
- `invoice`

Expected behavior:

- layouts no longer need hardcoded business-module links
- registry keys, DB module keys, and tenant-module keys all match exactly

Do not do yet:

- final dynamic filtering in layouts

Verify:

- every planned module has a registry entry
- route mapping is consistent

### Step 15. Implement Permission Resolution In Code

Goal:

Apply the core rule consistently:

- DB decides whether a module exists for tenant
- code decides what role can do inside the module

Scope:

- add code-based permission map for roles
- calculate effective permissions using:
  - scope
  - selected or resolved tenant
  - active module keys
  - role permission map

Expected behavior:

- module access requires both:
  - module enabled
  - role allowed

Verify:

- disabled module never appears as usable
- enabled module is still blocked if role is not allowed

### Step 16. Generate Navigation From Permissions

Goal:

Replace hardcoded layout navigation with generated navigation.

Scope:

- create nav composable/store
- build visible menu items from:
  - scope
  - selected tenant context
  - active module keys
  - role permission map
- wire layouts to that generated list

Expected behavior:

- `/platform`, `/app`, and tenant-specific `/shop` each show only allowed links

Verify:

- changing tenant modules changes visible nav
- changing role changes visible nav
- switching tenant changes visible nav
- layouts render correctly with no hardcoded business-module assumptions

### Step 17. Upgrade Route Guards

Goal:

Protect routes using both auth and module access.

Scope:

- keep login/scope checks
- add tenant-resolution checks for customer routes
- add selected-tenant checks for internal app routes
- add module-aware checks
- block access when:
  - tenant unresolved
  - module disabled
  - role not allowed

Expected behavior:

- hidden nav item cannot still be opened directly by URL

Verify:

- direct route access is blocked when permission fails
- valid route access still works

### Step 18. Build Customer Group Admin UI

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

### Step 19. Finish Shop Area Integration

Goal:

Make `/shop` fully use customer-group login and permission context.

Scope:

- update tenant-specific shop login flow
- update shop shell
- update shop guards
- ensure shop routes use customer actor context, not internal membership logic

Verify:

- shop login follows customer-group access only
- shop login follows tenant-specific route context
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

- the master plan already expects `public_domain`
- tenant-resolved login cannot be finished until tenant schema supports it
- it is the cleanest foundation for both admin selector work and customer entry work
