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

Prefer Quasar default components first.

Global layout helpers and shared tokens live in:

- [`web/src/css/app.scss`](/Users/david/Desktop/projects/group/brandwala-wholesale-quasar-v2/web/src/css/app.scss)

## Standard Page Flow

For list, catalog, and management pages, use this order:

1. `q-page` with class `bw-page`
2. wrapper with class `bw-page__stack`
3. simple page heading
4. optional `q-banner` for error state with class `bw-status-banner`
5. `q-card` when a section container is needed
6. one of:
   - `q-card` grid
   - `q-table`
   - direct section content
7. simple empty state text or a `q-card` empty section

Do not scatter unrelated floating actions around the page unless there is a strong product reason.

## Shared Patterns

Use Quasar defaults:

- page heading with normal text elements
- `q-card` for grouped sections
- `q-table` for row-based data
- plain text empty states when enough

## Design Rules

### Layout

- use `bw-page` for page padding
- use `bw-page__stack` for vertical rhythm
- use `bw-entity-grid` for standard card grids
- use `bw-inline-actions` for grouped action buttons
- keep sections left-aligned and business-oriented
- use fewer wrapper `div`s
- prefer semantic tags or Quasar sections when they already fit

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
- use default Quasar `q-btn` styles
- keep button text short and action-based

### Cards

- use plain `q-card`
- keep content simple
- avoid custom card shells

### Tables

- use `q-table`
- keep column labels short
- prefer explicit operational actions
- keep empty handling simple

### Simple Entry Screens

For small input-plus-list screens:

- prefer native Quasar building blocks like `q-card`, `q-input`, `q-btn`, and `q-markup-table`
- keep only the important text
- use theme colors instead of one-off colors
- avoid decorative wrappers when a plain Quasar layout is enough
- do not add custom visual styling if Quasar default already works

## Theme Rules

The app already has shared visual tokens in:

- [`web/src/css/app.scss`](/Users/david/Desktop/projects/group/brandwala-wholesale-quasar-v2/web/src/css/app.scss)
- [`web/src/components/WorkspaceShell.vue`](/Users/david/Desktop/projects/group/brandwala-wholesale-quasar-v2/web/src/components/WorkspaceShell.vue)

Follow these rules:

- use existing theme variables
- use `var(--bw-theme-...)` tokens
- do not hardcode unrelated colors unless needed for status or domain-specific meaning
- keep platform, app, and shop visually related but theme-aware
- do not override Quasar defaults globally unless there is a real product need

## What AI Should Do

When asked to build a new UI page, AI should:

1. check whether the page is a list page, detail page, form page, or data table page
2. use Quasar defaults before creating new abstractions
3. keep the page flow consistent with tenant and module pages
4. add new shared UI only when the pattern is truly reusable
5. avoid introducing new one-off card styles for common business entities

## What AI Should Not Do

Avoid these mistakes:

- building custom wrapper components when plain Quasar components already fit
- adding refresh buttons by default in app management pages
- using floating sticky buttons for common create actions when header actions are enough
- mixing multiple layout styles on similar CRUD pages
- using plain text empty states without guidance
- hardcoding colors that ignore the existing theme tokens
- adding custom visual treatments when default Quasar UI is enough

## Reference Pages

Use these pages as the current reference implementation:

- [`web/src/modules/tenant/pages/TenantPage.vue`](/Users/david/Desktop/projects/group/brandwala-wholesale-quasar-v2/web/src/modules/tenant/pages/TenantPage.vue)
- [`web/src/modules/tenant/pages/AdminTenantPage.vue`](/Users/david/Desktop/projects/group/brandwala-wholesale-quasar-v2/web/src/modules/tenant/pages/AdminTenantPage.vue)
- [`web/src/modules/featureCatalog/pages/ModulesPage.vue`](/Users/david/Desktop/projects/group/brandwala-wholesale-quasar-v2/web/src/modules/featureCatalog/pages/ModulesPage.vue)

These pages define the current standard for:

- page heading
- section layout
- card grid
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
