# Page Header Standard

Canonical rules for list and detail page headers. Follow this when creating or refactoring any page chrome so headers stay consistent, scannable, and mobile-friendly.

Related: [UI_CONSISTENCY.md](./UI_CONSISTENCY.md) · component `web/src/components/ui/AppPageHeader.vue` · filters `web/src/components/FilterSidebar.vue`

---

## Goals

1. **One mental model** — identity left, primary work right.
2. **Table stays usable** — do not hide filters to save height; constrain the table viewport instead.
3. **Mobile first** — one primary CTA visible; secondary actions in a menu; filters in a bottom sheet on phone.
4. **No hero-card titles** — do not wrap page titles in `.hero-surface` / floating title cards. Use flat `AppPageHeader`.

---

## Anatomy (top → bottom)

```
[ Breadcrumbs ]          ← detail / nested pages only
[ AppPageHeader ]        ← identity + status + primary action(s)
[ Toolbar / rates ]      ← search, filter trigger, view toggle, rates strip
[ Content ]              ← table / cards / sections
[ FilterSidebar ]        ← filters only (not in the header)
```

Page shell:

```vue
<q-page class="bw-page">
  <div class="bw-page__stack">
    <!-- breadcrumbs (detail only) -->
    <!-- AppPageHeader -->
    <!-- optional toolbar / rates -->
    <!-- content -->
  </div>
</q-page>
```

Ops-dense pages may use tighter padding (`q-pa-xs q-sm-pa-sm` + small vertical gaps) **without** reverting to a hero title card.

---

## 1. AppPageHeader (required for module pages)

Use `AppPageHeader` from `src/components/ui/AppPageHeader.vue`.

| Prop / slot | Use |
|-------------|-----|
| `eyebrow` | Module or section label (uppercase). Optional on list; useful on detail when no breadcrumbs yet. |
| `title` | Current page name (list: module name; detail: entity name). |
| `subtitle` | One short helper line (list purpose, or `Created for X` / order number). |
| `dense` | Prefer `true` on ops list + detail pages to keep the table in view. |
| `#action` | Status + **one** primary CTA (+ overflow menu on mobile). Slot name is `action` (singular). |

### Do

- Flat header — no `q-card` / `.hero-surface` around the title.
- Max **one** primary filled button in the action slot (e.g. Create, Add Item).
- Put secondary actions in `q-btn-dropdown` / `more_vert` menu.
- Use theme tokens (`--bw-theme-*`); no hardcoded hex in header styles.

### Don’t

- Put search or filter fields inside `AppPageHeader`.
- Put more than ~2–3 visible buttons on desktop without collapsing the rest.
- Duplicate the title in a large card below the header.

### List page example

```
eyebrow:  (optional) PRODUCT BASED COSTING
title:    Product Based Costing
subtitle: Manage costing files and open details
action:   [ Create Costing File ]
```

### Detail page example

```
breadcrumbs: Product Based Costing › #42 Summer UK
title:       Summer UK          (or file name)
subtitle:    Created for Wholesale Q3
action:      [ status chip ] [ Add Item ] [ ⋮ Actions ]
```

Order-style detail (customer / dropship):

```
eyebrow or crumbs: Order Portal / Shop Orders › ORD-…
title:             Order details
subtitle:          Details for Order ORD-…
action:            [ STATUS badge ]
```

Optional back control: place a flat `arrow_back` **before** the header copy (same row as title block), or rely on the breadcrumb parent link. Prefer breadcrumb parent link when crumbs exist; keep an explicit back only if there is no crumb row.

---

## 2. Breadcrumbs (detail / nested only)

### When

| Page | Breadcrumbs? |
|------|----------------|
| Module list / home | **No** — shell nav + header is enough |
| Entity detail (costing file, order, shipment, invoice) | **Yes** |
| Nested tool (preview, print, allocate from parent) | **Yes** if reachable from a parent entity |

### Rules

- One slim row **above** `AppPageHeader`.
- **2–3 segments max.**
- Parents are links; **current page is plain text** (not a link).
- Do not repeat the full `AppPageHeader` title as a long crumb — use short labels (`#42 Summer UK`, order number).
- Separator: Quasar `q-breadcrumbs` default or `›`.
- On mobile: allow horizontal scroll or truncate middle segments; keep the parent link tappable.

### Example

`Product Based Costing` → `#42 Summer UK` → `Preview`

---

## 3. Toolbar (below header)

Separate from the header. Typical list toolbar:

| Control | Placement |
|---------|-----------|
| Search | Always visible preferred; icon→expand only if space is extreme |
| Filter trigger | `filter_alt` icon button + badge for active filter count |
| View toggle | Table / cards (`q-btn-toggle`) — optional |
| Status / quick chips | Optional; **full filter sets stay in the sidebar** |

Detail pages may use a second band for rates / metadata (conversion rate, cargo, profit) — not inside `AppPageHeader`.

---

## 4. Filters — always in FilterSidebar

**Filters never live in the page header.**

- Trigger: toolbar `filter_alt` button with floating badge when count &gt; 0.
- Panel: `FilterSidebar` (`web/src/components/FilterSidebar.vue`).
- Contents: filter fields + Reset / Apply (follow existing list-page patterns).

### Responsive behavior (required)

| Breakpoint | Panel |
|------------|--------|
| `sm` and up | Side panel (right), current desktop behavior |
| below `sm` (phone) | **Bottom sheet** — full width, ~70–85vh, slide up |

Implement the bottom-sheet mode **inside** `FilterSidebar` so every consumer gets it. Do not invent per-page filter drawers.

Even a single status filter still opens from the sidebar (consistency over inline-only filters). Search may stay inline on the toolbar.

---

## 5. Actions — progressive disclosure

| Breakpoint | Visible in header `#action` |
|------------|-----------------------------|
| `≥ sm` | Status + primary CTA + optional 1–2 secondary outline buttons **or** one Actions dropdown |
| `< sm` | Status + **one** primary CTA (full-width if alone) + `more_vert` / Actions menu for everything else |

**File details mapping (example)**

- Always primary: **Add Item**
- Menu / secondary: Bulk Paste, Add from Catalog, Columns, Preview, PDF, Excel
- Status: interactive chip (menu to change status) stays visible when possible

Touch: prefer ≥ 40px control height on xs.

---

## 6. Keeping the table on screen

Do **not** solve viewport pressure by collapsing search/filters into mystery icons only.

Preferred:

1. `AppPageHeader` with `dense`.
2. No title hero card.
3. Give the table its own scrollport:

```css
.q-table__middle {
  max-height: calc(100vh - 280px); /* tune per shell + header + toolbar */
  overflow: auto;
}
thead tr th {
  position: sticky;
  top: 0;
  z-index: 2;
  background: var(--bw-theme-surface);
}
```

Reference patterns: `.inventory-page__table` in `web/src/css/app.scss`, thrift shipment table wraps.

### Mobile content

- List: prefer **card** view under `sm`, or allow user toggle with card as default.
- Wide detail tables: horizontal scroll inside a wrap (`TreasuryTableWrap` / overflow-x); do not shrink max-height so aggressively that only 1–2 rows show — prefer page scroll or `min(60vh, …)` on phone.

---

## 7. Checklist (copy when editing a page)

- [ ] `q-page` uses `bw-page` + `bw-page__stack` (or documented dense ops padding)
- [ ] Title uses `AppPageHeader` (not a hero title card)
- [ ] `dense` on ops list/detail
- [ ] Breadcrumbs only on detail/nested; parents linkable; current plain
- [ ] Exactly one primary CTA in header actions
- [ ] Secondary actions collapsed on phone
- [ ] Search/filters **not** inside the header
- [ ] Filters only via `FilterSidebar` (side desktop / bottom phone)
- [ ] Active filter count badge on the filter button
- [ ] Table scrollport + sticky thead when the page is table-heavy
- [ ] Colors via `--bw-theme-*` / Quasar props — no hardcoded hex in header CSS
- [ ] i18n for user-visible strings where the module already uses i18n

---

## 8. Migration notes

When updating an existing page:

1. Replace hero title `q-card` / `.hero-surface` header with `AppPageHeader`.
2. Move Create / Add primary button into `#action`.
3. Move secondary buttons into Actions / `more_vert` (especially on detail).
4. Keep or add toolbar row for search + filter icon.
5. Keep using `FilterSidebar`; plan shared bottom-sheet behavior for phone.
6. On detail: add breadcrumb row; drop redundant back **or** keep back only if crumbs are absent.
7. Tune table `max-height` after header height changes.

Reference pages (target shapes, not yet all migrated):

- List identity: `CustomerOrderDetailPage`-style flat hierarchy + `AppPageHeader` for module lists (`ProductBasedCostingPage`).
- Detail density: `ProductBasedCostingFileDetailsPage` actions → header `#action` + overflow; rates stay in a band below.

---

## 9. Out of scope

- Shop storefront marketing heroes (branded shopfront pages follow shop UI docs, not this ops header).
- Dialog / drawer titles (use dialog section headers).
- Treasury-specific shells may keep `TreasuryPageShell` + `AppPageHeader`; still follow breadcrumb and filter rules above.
