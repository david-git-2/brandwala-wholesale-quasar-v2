# Frontend Changes Needed Now

## Purpose

This document lists the frontend structure issues that should be changed in the current project before more features are added.

The current project is workable, but it is still shaped around the earlier auth model and a smaller scope. If left as-is, it will become harder to scale into the planned `platform`, `app`, and `shop` architecture.

## Current Problems

### 1. Shop roles are outdated in the frontend

Current frontend logic still treats shop access as roles like `customer` and `viewer`.

But the current product plan says customer-side access should come from customer-group members with roles:

- `admin`
- `negotiator`
- `staff`

This means the auth pages, route guards, and auth store model will need to change.

## 2. One auth member shape is carrying too much responsibility

The frontend currently stores one shared member snapshot for all scopes.

That is no longer a good long-term fit because:

- internal users come from `memberships`
- shop users will come from `customer_group_members`

This should be redesigned before customer-side features grow.

## 3. Scope boundaries are not visible enough in the module structure

The project uses feature folders, which is good, but the scopes are still mixed inside those features.

Examples:

- tenant pages exist for both `/platform` and `/app` inside the same feature folder
- dashboard pages for all scopes live together

This is manageable now, but will get harder as each scope adds more pages.

## 4. The `modules/modules` naming should be changed

The current folder name is confusing.

It should be renamed to something clearer, such as:

- `feature-catalog`
- `platform-modules`
- `tenant-modules`

The final name should reflect the business meaning.

## 5. Folder conventions are inconsistent

The codebase mixes:

- `store`
- `stores`

This should be standardized immediately.

Recommended convention:

- always use `stores`

## 6. Some stores are already becoming too broad

The current tenant store is handling multiple concerns:

- tenant CRUD
- tenant listing by role/membership
- tenant module loading
- admin-oriented tenant queries

This is a warning sign.

Before more business features are added, the store responsibilities should be split.

## 7. Router organization should become more scope-oriented

The app already has clear route prefixes:

- `/platform`
- `/app`
- `/shop`

But the route ownership is still mostly feature-flat.

The routing layer should gradually move toward scope-based grouping so future features fit cleanly.

## What Should Be Changed First

### High priority

1. Update auth and route role assumptions for `/shop`
2. Redesign the auth access model so internal and shop actors are not forced into one identical shape
3. Rename `modules/modules`
4. Standardize on `stores`

### Medium priority

1. Split broad stores into smaller focused stores
2. Reorganize routes so scope boundaries are clearer
3. Separate platform, tenant, and shop dashboards more explicitly

### Lower priority

1. Move shared code into dedicated shared folders only where truly needed
2. Refine naming across modules for long-term clarity

## Suggested Immediate Refactor Direction

These are the most useful near-term changes:

- keep `auth` shared
- keep `tenant`, `membership`, and current platform features working
- introduce new customer-side features under a separate shop-oriented structure
- avoid adding new business features into the current mixed folders
- start the reorganization before building order, cart, negotiation, and customer group flows

## Safe Transition Plan

### Phase 1

- fix role assumptions in auth
- rename confusing folders
- standardize folder naming conventions

### Phase 2

- split oversized stores
- move customer-side features into dedicated shop modules
- create dedicated customer-group and customer-group-member modules

### Phase 3

- reorganize the route tree around `platform`, `app`, and `shop`
- align layouts, guards, and route modules with those three scopes

## Summary

The current project structure is acceptable for the current size, but it should be changed before the next major feature phase.

The most important changes right now are:

- fix shop role assumptions
- separate internal and customer-side access models
- standardize naming
- reduce broad multi-purpose stores
