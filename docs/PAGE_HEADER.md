# Page Header (AI spec) — LOCKED

**List golden reference (do not drift):** `web/src/modules/product_based_costing/pages/ProductBasedCostingPage.vue`  
**Detail golden reference (do not drift):** `web/src/modules/product_based_costing/pages/ProductBasedCostingFileDetailsPage.vue`  
**Same header DNA:** `ShopOrdersPage.vue`, `DropshipOrdersPage.vue`, `CustomerOrderDetailPage.vue`  
**Same status workflow DNA:** `DropshipOrderDetailPage.vue` (shipment flow), costing file details (file lifecycle)

When editing any list/detail page header, **copy this markup**. Do not substitute `AppPageHeader`, `.bw-page`, `.hero-surface`, or alternate padding classes.

---

## Frozen classes (exact strings)

| Piece | Exact class / markup |
|-------|----------------------|
| Page | `q-page class="q-pa-md"` |
| Stack | `div class="q-gutter-y-md"` |
| Header row | `section class="row items-center justify-between q-col-gutter-md"` |
| Overline | `div class="text-overline text-primary"` |
| Title | `h1 class="text-h5 text-weight-bold q-my-none"` |
| CTA wrap | `div class="col-auto"` |
| Primary CTA (list) | `q-btn color="primary" unelevated no-caps class="pill-btn"` |
| Primary CTA (detail) | `q-btn color="primary" unelevated no-caps` (no `pill-btn`, no `round`) |
| Toolbar card | `q-card flat bordered class="q-pa-sm"` |
| Toolbar row | `div class="row items-center justify-between q-col-gutter-sm"` |
| Filters | `FilterSidebar` + toolbar `filter_alt` + badge |
| Status workflow btn | `dense no-caps class="q-px-md text-caption text-weight-bold"` |
| Status chevron | `q-icon name="chevron_right" color="grey-5" size="18px"` |

**Also fixed globally (do not override):** `.q-page` → `max-width: 1200px`, `background: var(--bw-theme-surface, #ffffff)`.

---

## MUST

1. Use the LIST or DETAIL template below verbatim (only swap labels/handlers).
2. One primary filled CTA in the header `col-auto`.
3. List search/filter/view controls live **inside** the bordered toolbar card — never a floating icon row under the title.
4. Filters only in `FilterSidebar` (desktop side / phone bottom sheet).
5. Route meta: `hasPageToolbar: true` when the shell title would duplicate the `h1`.
6. Detail lifecycle status uses the **status workflow strip** (below) — not a header chip + menu.

## MUST NOT

- `AppPageHeader` for these pages
- `q-pa-xs` / `q-pa-sm q-sm-pa-md` / `q-pa-none` / custom padding CSS
- `.bw-page` / `.bw-page__stack` / `.bw-page-fill` on new header work (order shop pages that already use `bw-page` may keep it; new work uses `q-pa-md`)
- `.hero-surface` title cards
- List subtitle under `h1`
- Overline text that only repeats the `h1` (overline = short module label, e.g. `Costing`)
- Extra wrappers that add vertical gap between overline and `h1`
- Header status as clickable `q-chip` + `q-menu` (legacy — replace when touching the page)
- `round` / `pill-btn` on detail header actions

---

## LIST template (copy exactly)

```vue
<q-page class="q-pa-md">
  <div class="q-gutter-y-md">
    <section class="row items-center justify-between q-col-gutter-md">
      <div class="col">
        <div class="text-overline text-primary">Costing</div>
        <h1 class="text-h5 text-weight-bold q-my-none">Product Based Costing</h1>
      </div>
      <div class="col-auto">
        <q-btn
          color="primary"
          unelevated
          no-caps
          class="pill-btn"
          label="Create Costing File"
          @click="openCreateDialog"
        />
      </div>
    </section>

    <q-card flat bordered class="q-pa-sm">
      <div class="row items-center justify-between q-col-gutter-sm">
        <div class="col-auto row items-center q-gutter-sm">
          <!-- search control -->
          <!-- filter_alt + q-badge when activeFilterCount > 0 -->
        </div>
        <div class="col-auto">
          <!-- optional q-btn-toggle table/card -->
        </div>
      </div>
    </q-card>

    <!-- table / cards -->

    <FilterSidebar v-model="filterDrawerOpen" title="Filters">
      <!-- filter fields + Reset -->
    </FilterSidebar>
  </div>
</q-page>
```

Reference implementation: `ProductBasedCostingPage.vue` (header + toolbar card already match).

---

## DETAIL template (copy exactly)

```vue
<q-page class="q-pa-md">
  <div class="q-gutter-y-md">
    <section class="row items-center justify-between q-col-gutter-md">
      <div class="col">
        <div class="row items-center q-gutter-x-sm">
          <q-btn flat dense icon="arrow_back" color="grey-7" @click="goBack" />
          <div>
            <div class="text-overline text-primary">Product Based Costing</div>
            <h1 class="text-h5 text-weight-bold q-my-none">{{ name }}</h1>
            <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">Created for {{ orderFor }}</p>
          </div>
        </div>
      </div>
      <div class="col-auto row q-gutter-sm items-center">
        <q-btn color="primary" unelevated no-caps label="Add Item" />
        <q-btn flat dense icon="more_vert" aria-label="Actions">
          <q-menu><!-- secondary actions --></q-menu>
        </q-btn>
      </div>
    </section>

    <!-- status (+ optional secondary) toolbar — see STATUS WORKFLOW below -->
    <!-- table: full-width q-card flat bordered, no nested title chrome -->
  </div>
</q-page>
```

Detail meta line (`text-body2`) is allowed. List pages: **no** meta line.

Optional breadcrumbs: only if needed instead of overline; then `q-breadcrumbs class="q-mb-xs text-caption"` directly above `h1`, gap = `q-mb-xs` only.

---

## Status workflow strip (LOCKED for detail pages)

**Golden ref:** `ProductBasedCostingFileDetailsPage.vue`  
**Also matches:** `DropshipOrderDetailPage.vue` shipment status bar

When a detail page has a **lifecycle status** the user can change, use this pattern. When modifying an existing detail page that still uses a chip/menu status control, **migrate to this strip**.

### Rules

1. Live in `q-card flat bordered class="q-pa-sm"` **under** the page header — not inside the `h1` row.
2. Linear workflow states as a row of dense square `q-btn`s separated by `chevron_right`.
3. Current state: filled (`unelevated`) + status color + `check_circle` icon; others outline; passed states muted (`grey-5` / `grey-9`).
4. Terminal / abort state (e.g. `cancelled`, `returned`) sits **aside** after a vertical separator — not in the linear chevron chain as a normal next step.
5. Humanize labels (`formatStatusLabel` / replace `_` with spaces + title case). No raw snake_case in the UI.
6. Loading: `:loading` on the clicked target only; disable siblings while updating.
7. No title/hint row above the buttons (save vertical space for the main table).
8. Optional secondary controls (rates, filters summary) share the **same** toolbar card on the right — collapse heavy editors by default (summary caption + expand toggle).

### Markup skeleton

```vue
<q-card flat bordered class="q-pa-sm">
  <div class="row items-center justify-between q-col-gutter-sm">
    <div class="col-grow row items-center q-gutter-xs status-workflow-row">
      <template v-for="(st, idx) in workflowStatuses" :key="st">
        <q-btn
          :color="status === st ? getStatusColor(st) : isPassedStatus(st) ? 'grey-5' : 'grey-3'"
          :text-color="status === st ? 'white' : isPassedStatus(st) ? 'grey-9' : 'grey-7'"
          :outline="status !== st"
          :unelevated="status === st"
          dense
          no-caps
          class="q-px-md text-caption text-weight-bold"
          :loading="updatingStatus && targetUpdatingStatus === st"
          :disable="updatingStatus && targetUpdatingStatus !== st"
          @click="onUpdateStatus(st)"
        >
          <q-icon v-if="status === st" name="check_circle" size="14px" class="q-mr-xs" />
          {{ formatStatusLabel(st) }}
        </q-btn>
        <q-icon
          v-if="idx < workflowStatuses.length - 1"
          name="chevron_right"
          color="grey-5"
          size="18px"
          class="status-workflow-chevron"
        />
      </template>
      <q-separator vertical class="q-mx-sm status-workflow-sep" />
      <q-btn
        :color="status === 'cancelled' ? 'negative' : 'grey-3'"
        :text-color="status === 'cancelled' ? 'white' : 'grey-7'"
        :outline="status !== 'cancelled'"
        :unelevated="status === 'cancelled'"
        dense
        no-caps
        class="q-px-md text-caption text-weight-bold"
        :loading="updatingStatus && targetUpdatingStatus === 'cancelled'"
        :disable="updatingStatus && targetUpdatingStatus !== 'cancelled'"
        @click="onUpdateStatus('cancelled')"
      >
        Cancelled
      </q-btn>
    </div>
    <!-- optional: summary + expand for secondary editors (rates, etc.) -->
  </div>
</q-card>
```

### MUST NOT (status)

- Clickable `q-chip` + dropdown menu for lifecycle status on detail pages
- Full-width status card with large title/subtitle when a single button row suffices
- Putting status only in the header action cluster next to the primary CTA

---

## Checklist (fail = reject PR)

- [ ] `class="q-pa-md"` on `q-page`
- [ ] `class="q-gutter-y-md"` stack
- [ ] Header = `text-overline text-primary` + `h1.text-h5.text-weight-bold.q-my-none`
- [ ] List primary CTA = `unelevated no-caps pill-btn` in `col-auto`
- [ ] Detail primary CTA = `unelevated no-caps` (no `pill-btn` / `round`)
- [ ] List toolbar = `q-card flat bordered q-pa-sm`
- [ ] Detail lifecycle status = workflow button strip (not chip menu)
- [ ] No `AppPageHeader`, no hero title card, no list subtitle
- [ ] `FilterSidebar` for filters
- [ ] `hasPageToolbar: true` when shell title duplicates `h1`
