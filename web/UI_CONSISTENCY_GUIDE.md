# UI Consistency Guide

## Purpose

This document defines the UI pattern that should be followed when building or updating pages in the Quasar app.

The goal is simple:

- keep page flow consistent
- keep cards consistent
- keep tables consistent
- avoid one-off page layouts
- give AI a clear pattern to follow

This guide should be used whenever a new admin, platform, app, or shop page is created.

## Core Rule

Do not build raw page layouts from scratch if the page fits an existing shared pattern.

Prefer shared UI building blocks first.

Current shared UI components live in:

- [`web/src/components/ui/AppPageHeader.vue`](/Users/david/Desktop/projects/group/brandwala-wholesale-quasar-v2/web/src/components/ui/AppPageHeader.vue)
- [`web/src/components/ui/AppSectionCard.vue`](/Users/david/Desktop/projects/group/brandwala-wholesale-quasar-v2/web/src/components/ui/AppSectionCard.vue)
- [`web/src/components/ui/AppEntityCard.vue`](/Users/david/Desktop/projects/group/brandwala-wholesale-quasar-v2/web/src/components/ui/AppEntityCard.vue)
- [`web/src/components/ui/AppEmptyState.vue`](/Users/david/Desktop/projects/group/brandwala-wholesale-quasar-v2/web/src/components/ui/AppEmptyState.vue)
- [`web/src/components/ui/AppDataTable.vue`](/Users/david/Desktop/projects/group/brandwala-wholesale-quasar-v2/web/src/components/ui/AppDataTable.vue)

Global layout helpers and shared tokens live in:

- [`web/src/css/app.scss`](/Users/david/Desktop/projects/group/brandwala-wholesale-quasar-v2/web/src/css/app.scss)

## Standard Page Flow

For list, catalog, and management pages, use this order:

1. `q-page` with class `bw-page`
2. wrapper with class `bw-page__stack`
3. `AppPageHeader`
4. optional `q-banner` for error state with class `bw-status-banner`
5. `AppSectionCard`
6. one of:
   - `AppEntityCard` grid
   - `AppDataTable`
   - a section body built inside `AppSectionCard`
7. `AppEmptyState` for no-data situations

Do not scatter unrelated floating actions around the page unless there is a strong product reason.

## Shared Patterns

### 1. Page Header

Use `AppPageHeader` for:

- page title
- subtitle
- eyebrow label
- right-side actions

Good use cases:

- `Add Tenant`
- `Add Module`
- `Export`
- `Filter`

Avoid:

- repeating the same title again inside the section card
- large custom hero blocks for normal CRUD pages

## 2. Section Card

Use `AppSectionCard` as the main container for:

- data grids
- forms
- table sections
- grouped lists

This is the default section shell for admin pages.

Avoid raw `q-card` wrappers for standard management sections unless the layout is genuinely special.

## 3. Entity Card

Use `AppEntityCard` for compact list and catalog items like:

- tenants
- modules
- customer groups
- stores
- users

Entity cards should follow this structure:

- eyebrow
- title
- meta
- optional description
- optional status badge
- optional action row

Do not create a different card layout for every page if the item is still just an entity in a collection.

## 4. Empty State

Use `AppEmptyState` instead of plain text like:

- "No data found"
- "No tenants found"

Each empty state should teach the user what this area is for and what action they can take next.

## 5. Table Pattern

Use `AppDataTable` for pages that are better represented as rows instead of cards.

Examples:

- permissions
- memberships
- audit logs
- reports
- large operational datasets

If a page starts with cards and later grows into many columns or bulk actions, switch it to the table pattern instead of forcing everything into cards.

## Design Rules

### Layout

- use `bw-page` for page padding
- use `bw-page__stack` for vertical rhythm
- use `bw-entity-grid` for standard card grids
- use `bw-inline-actions` for grouped action buttons
- keep sections left-aligned and business-oriented

### Content Density

- tenant and module pages are management screens, not marketing pages
- keep them clean and structured
- avoid oversized decorative areas
- avoid deeply nested cards

### Buttons

- one primary action is enough in most headers
- use secondary buttons only when truly needed
- for the app flow, do not add refresh buttons by default
- do not add floating FABs if the same action can live clearly in the header

### Cards

- use the shared card shell first
- status should use the built-in badge area
- actions should sit in the bottom action row
- keep titles and descriptions clamped instead of letting cards stretch unpredictably

### Tables

- wrap tables in `AppDataTable`
- keep column labels short
- prefer explicit operational actions
- empty state should still use the shared empty-state pattern

## Theme Rules

The app already has shared visual tokens in:

- [`web/src/css/app.scss`](/Users/david/Desktop/projects/group/brandwala-wholesale-quasar-v2/web/src/css/app.scss)
- [`web/src/components/WorkspaceShell.vue`](/Users/david/Desktop/projects/group/brandwala-wholesale-quasar-v2/web/src/components/WorkspaceShell.vue)

Follow these rules:

- use existing theme variables
- use `var(--bw-theme-...)` tokens
- do not hardcode unrelated colors unless needed for status or domain-specific meaning
- keep platform, app, and shop visually related but theme-aware

## What AI Should Do

When asked to build a new UI page, AI should:

1. check whether the page is a list page, detail page, form page, or data table page
2. reuse the shared components before creating new ones
3. keep the page flow consistent with tenant and module pages
4. add new shared UI only when the pattern is truly reusable
5. avoid introducing new one-off card styles for common business entities

## What AI Should Not Do

Avoid these mistakes:

- building a page with raw `q-card` blocks when `AppSectionCard` or `AppEntityCard` already fits
- adding refresh buttons by default in app management pages
- using floating sticky buttons for common create actions when header actions are enough
- mixing multiple layout styles on similar CRUD pages
- using plain text empty states without guidance
- hardcoding colors that ignore the existing theme tokens

## Reference Pages

Use these pages as the current reference implementation:

- [`web/src/modules/tenant/pages/TenantPage.vue`](/Users/david/Desktop/projects/group/brandwala-wholesale-quasar-v2/web/src/modules/tenant/pages/TenantPage.vue)
- [`web/src/modules/tenant/pages/AdminTenantPage.vue`](/Users/david/Desktop/projects/group/brandwala-wholesale-quasar-v2/web/src/modules/tenant/pages/AdminTenantPage.vue)
- [`web/src/modules/featureCatalog/pages/ModulesPage.vue`](/Users/david/Desktop/projects/group/brandwala-wholesale-quasar-v2/web/src/modules/featureCatalog/pages/ModulesPage.vue)

These pages define the current standard for:

- page header
- section shell
- entity grid
- shared empty state
- action placement

## Example Direction

### If the page is a simple management list

Use:

- `AppPageHeader`
- `AppSectionCard`
- `AppEntityCard`
- `AppEmptyState`

### If the page is a dense operational screen

Use:

- `AppPageHeader`
- `AppDataTable`
- `AppEmptyState`

### If the page is a detail view

Use:

- `AppPageHeader`
- one or more `AppSectionCard` sections
- shared action placement

Try to keep the same spacing and structure as the list pages.

## When To Create A New Shared Component

Create a new shared UI component only if:

- the pattern appears in at least two pages
- it solves a real consistency problem
- it is more than a one-page visual tweak

If a page is unique, keep the uniqueness inside the page.
If many pages need the same pattern, move it into `web/src/components/ui`.

## Summary

The design system for this app is now:

- shared header
- shared section shell
- shared entity card
- shared empty state
- shared table shell
- shared page spacing and theme tokens

Future UI work should extend this system instead of bypassing it.
