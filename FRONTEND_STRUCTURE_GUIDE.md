# Frontend Structure Guide

## Purpose

This document defines the frontend structure that should be followed going forward.

The app has three primary scopes:

- `platform` for superadmin
- `app` for tenant internal users
- `shop` for customer-side users

Because these scopes have different layouts, permissions, and business flows, the frontend structure should reflect those boundaries clearly.

## Core Principle

Use a scope-first and feature-second structure.

That means:

- top-level separation by application area
- feature folders inside each area
- shared items only in shared locations when they are truly reused

## Recommended Structure

```text
web/src/
  app/
    router/
    layouts/
    boot/
    shared/
      components/
      composables/
      utils/
      types/
    modules/
      auth/
      platform/
        dashboard/
        tenants/
        feature-catalog/
      tenant/
        dashboard/
        memberships/
        customer-groups/
        tenant-settings/
      shop/
        dashboard/
        customer-account/
        cart/
        orders/
        negotiation/
```

## Folder Rules

Each feature module should follow one consistent pattern:

```text
feature-name/
  components/
  pages/
  routes/
  stores/
  services/
  repositories/
  types/
```

Rules:

- use `stores`, not `store`
- use `services` for business logic
- use `repositories` for Supabase access
- use `types` for feature-local types
- use `components` only for that feature’s UI parts
- move reusable UI to shared folders only when truly cross-feature

## Scope Boundaries

### Platform

Purpose:
- superadmin-only area

Examples:
- platform dashboard
- tenant management
- feature/module catalog
- tenant module assignment

### Tenant App

Purpose:
- internal tenant area

Examples:
- internal dashboard
- memberships
- customer groups
- customer group members
- tenant operational features

### Shop

Purpose:
- customer-facing area

Examples:
- customer dashboard
- product browsing
- cart
- order placement
- negotiation

## Auth Structure

Auth should stay shared at the top level because the login mechanism is the same for all scopes.

Recommended auth responsibilities:

- Google OAuth login flow
- callback processing
- session bootstrap
- scope detection
- route access guards

Important note:
- internal users and customer-side users should not be forced into the same frontend actor model if their backend source is different
- internal access comes from `memberships`
- customer-side access comes from `customer_group_members`

## Naming Rules

- avoid folder names like `modules/modules`
- use explicit names such as:
  - `feature-catalog`
  - `tenant-modules`
  - `customer-groups`
  - `customer-group-members`
- name features by business meaning, not generic technical words

## Routing Rules

Routes should be grouped by scope.

Examples:

- `/platform/...`
- `/app/...`
- `/shop/...`

Each scope should eventually have its own route tree and its own feature modules beneath it.

Recommended direction:

- one route entry for platform features
- one route entry for tenant internal features
- one route entry for shop features

## State Rules

Stores should be feature-focused, not catch-all stores.

Good examples:

- `tenantStore` for tenant CRUD only
- `tenantModuleStore` for tenant module assignment
- `membershipStore` for internal memberships
- `customerGroupStore` for customer groups
- `customerGroupMemberStore` for customer-side users

Avoid:

- putting tenant CRUD, tenant modules, membership-based lookups, and unrelated admin helpers into one store

## Shared Code Rules

Keep these shared:

- auth helpers
- common UI primitives
- Supabase boot setup
- global app types only when truly global

Do not move feature code into shared folders too early.

## Mobile Requirement

The frontend must stay mobile-responsive from the start because the app is planned to be packaged later with Capacitor for Android.

This means:

- pages should work well at phone sizes
- layouts should not assume desktop-only sidebars
- forms and tables should have responsive behavior
- route structure should remain compatible with both web and mobile packaging

## Summary

The structure to follow is:

- shared auth at the top
- scope-first organization for `platform`, `app`, and `shop`
- feature folders inside each scope
- consistent folder naming inside every feature
- smaller focused stores instead of broad catch-all feature stores
