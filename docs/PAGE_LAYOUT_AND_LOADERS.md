# Page Layout, Header & Skeleton Loaders Spec (Quasar Vue 3) — LOCKED

Quick-reference blueprint for implementing standard page structures, header controls, status workflows, and matching skeleton loaders (`q-skeleton`) across Quasar pages and components in the Brandwala codebase.

**List golden reference (do not drift):** `web/src/modules/product_based_costing/pages/ProductBasedCostingPage.vue`  
**Detail golden reference (do not drift):** `web/src/modules/product_based_costing/pages/ProductBasedCostingFileDetailsPage.vue`  
**Same header & status workflow DNA:** `ShopOrdersPage.vue`, `DropshipOrdersPage.vue`, `CustomerOrderDetailPage.vue`, `DropshipOrderDetailPage.vue`

---

## 1. Frozen UI Classes & Element Cheat Sheet

### Frozen Layout & Typography Classes (Exact Strings)

| UI Element | Class / Markup | Rules |
| :--- | :--- | :--- |
| **Page Container** | `q-page class="q-pa-md"` | `max-width: 1200px` globally |
| **Page Stack** | `div class="q-gutter-y-md"` | Standard vertical spacing |
| **Header Row** | `section class="row items-center justify-between q-col-gutter-md"` | Flex header row |
| **Overline** | `div class="text-overline text-primary"` | Short module label (e.g. `Costing`) |
| **Title (`h1`)** | `h1 class="text-h5 text-weight-bold q-my-none"` | Primary page title |
| **CTA Wrapper** | `div class="col-auto"` / `div class="col-auto row q-gutter-sm items-center"` | Header button cluster |
| **Primary CTA** | `q-btn color="primary" unelevated no-caps` | Standard filled primary action |
| **Toolbar Card** | `q-card flat bordered class="q-pa-sm"` | Filter, search, and view controls |
| **Toolbar Row** | `div class="row items-center justify-between q-col-gutter-sm"` | Responsive toolbar inner row |
| **Status Workflow Btn** | `dense no-caps class="q-px-md text-caption text-weight-bold"` | Detail lifecycle status button |
| **Status Chevron** | `q-icon name="chevron_right" color="grey-5" size="18px"` | Workflow step separator |

### Skeleton Loader Element Mapping

| UI Element | `q-skeleton` Pattern | Dimensions / Class |
| :--- | :--- | :--- |
| **Page Title (`h1`)** | `<q-skeleton type="text" width="220px" height="32px" />` | Matches `text-h5` line height |
| **Overline / Subtitle** | `<q-skeleton type="text" width="120px" height="14px" />` | Matches `text-overline` |
| **Primary CTA Button** | `<q-skeleton type="QBtn" width="110px" height="36px" />` | Standard 36px CTA height |
| **Status / Pill Badge** | `<q-skeleton type="QBadge" width="80px" height="24px" />` | Status badge replacement |
| **Input / Search Field** | `<q-skeleton type="QInput" height="40px" />` | Standard dense field height |
| **Card / Surface Block** | `<q-card flat bordered class="q-pa-md"><q-skeleton type="rect" height="150px" class="rounded-borders" /></q-card>` | Matches container radius |
| **Avatar / Profile** | `<q-skeleton type="QAvatar" size="40px" />` | Circular avatar |

---

## 2. Layout & Performance Core Rules

### Architectural Principles & Performance

1. **Zero Cumulative Layout Shift (CLS)**: Skeleton loaders must mirror the exact layout structure, spacing (`q-gutter-y-md`), and heights of actual loaded content.
2. **Minimal Code & Tokens**: Use `v-for="n in count"` for repeating items (cards, table rows, workflow buttons) rather than duplicating markup blocks.
3. **Theme Compatible**: `q-skeleton` natively uses Quasar CSS variables—never apply explicit hardcoded background colors to skeleton elements.
4. **Skeletons Over Spinners**: Use `q-skeleton` for initial page content loads to maintain layout context. Reserve `QSpinner` for micro-actions (e.g., button loading states).
5. **Separate Skeleton Component Architecture**: Skeleton loaders must NOT be inlined directly inside parent page SFCs. Extract page loading skeletons into separate dedicated components (e.g., `[Feature]Skeleton.vue` or `[Feature]DetailSkeleton.vue` in `components/`) to keep main page SFCs clean, modular, and maintainable.
6. **No Layout Disruption**: UI modernization and skeleton additions MUST NOT alter, move, or scramble the placement or layout ordering of existing components.
7. **No GPU Reflows**: Animate `transform` and `opacity` instead of `height`, `width`, or `margin`. Avoid heavy `backdrop-filter: blur()`.

---

## 3. List Page Pattern (Loaded + Skeleton)

List pages feature an overline module title, standard `h1`, single primary CTA, bordered toolbar card (search & filter controls), and filter sidebar.

### 3.1 Loaded List Page Template
```vue
<template>
  <q-page class="q-pa-md">
    <div class="q-gutter-y-md">
      <!-- Header -->
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline text-primary">Costing</div>
          <h1 class="text-h5 text-weight-bold q-my-none">Product Based Costing</h1>
        </div>
        <div class="col-auto">
          <q-btn color="primary" unelevated no-caps label="Create Costing File" @click="openCreateDialog" />
        </div>
      </section>

      <!-- Toolbar Card -->
      <q-card flat bordered class="q-pa-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col-12 col-sm-4 row items-center q-gutter-sm">
            <q-input v-model="searchQuery" dense outlined placeholder="Search files..." class="col-grow" />
            <q-btn flat dense icon="filter_alt" @click="filterDrawerOpen = true">
              <q-badge v-if="activeFilterCount" color="primary" floating>{{ activeFilterCount }}</q-badge>
            </q-btn>
          </div>
          <div class="col-auto">
            <!-- View toggle or secondary actions -->
          </div>
        </div>
      </q-card>

      <!-- Loaded Content Grid / Table -->
      <div class="row q-col-gutter-md">
        <!-- Content Cards -->
      </div>

      <FilterSidebar v-model="filterDrawerOpen" title="Filters">
        <!-- Filter controls -->
      </FilterSidebar>
    </div>
  </q-page>
</template>
```

### 3.2 Skeleton List Page Template
```vue
<template>
  <q-page class="q-pa-md">
    <div class="q-gutter-y-md">
      <!-- Header Skeleton -->
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <q-skeleton type="text" width="100px" height="14px" class="q-mb-xs" />
          <q-skeleton type="text" width="220px" height="32px" />
        </div>
        <div class="col-auto">
          <q-skeleton type="QBtn" width="120px" height="36px" />
        </div>
      </section>

      <!-- Toolbar Card Skeleton -->
      <q-card flat bordered class="q-pa-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col-12 col-sm-4">
            <q-skeleton type="QInput" height="36px" />
          </div>
          <div class="col-auto row q-gutter-x-sm">
            <q-skeleton type="QBtn" width="36px" height="36px" />
            <q-skeleton type="QBtn" width="90px" height="36px" />
          </div>
        </div>
      </q-card>

      <!-- Cards Skeleton Grid (6 Items) -->
      <div class="row q-col-gutter-md">
        <div v-for="n in 6" :key="n" class="col-12 col-sm-6 col-md-4">
          <q-card flat bordered class="q-pa-md">
            <div class="row items-center justify-between q-mb-sm">
              <q-skeleton type="text" width="60%" height="20px" />
              <q-skeleton type="QBadge" width="50px" height="20px" />
            </div>
            <q-skeleton type="text" width="40%" class="q-mb-md" />
            <q-skeleton type="rect" height="80px" class="rounded-borders q-mb-sm" />
            <div class="row justify-end">
              <q-skeleton type="QBtn" width="70px" height="28px" />
            </div>
          </q-card>
        </div>
      </div>
    </div>
  </q-page>
</template>
```

---

## 4. Detail Page Pattern & Status Workflow

Detail pages include a back button, overline, `h1`, optional subtitle meta line, action buttons, and a **Status Workflow Strip**.

### 4.1 Status Workflow Strip (LOCKED Rules)

1. **Location**: Standard bordered card (`q-card flat bordered class="q-pa-sm"`) directly **under** the header row.
2. **Step Display**: Linear workflow states rendered as dense square `q-btn`s separated by `chevron_right`.
3. **State Styling**:
   - Current state: Filled (`unelevated`) + status color + `check_circle` icon.
   - Other states: Outline; passed states muted (`grey-5` / `grey-9`).
   - Abort state (`cancelled`, `returned`): Placed **aside** after a vertical separator (`q-separator vertical`).
4. **Interactions**: Humanize labels (`formatStatusLabel`). `:loading` on clicked target only; disable siblings while updating.

### 4.2 Loaded Detail Page Template
```vue
<template>
  <q-page class="q-pa-md">
    <div class="q-gutter-y-md">
      <!-- Header -->
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

      <!-- Status Workflow Strip -->
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
              <q-icon v-if="idx < workflowStatuses.length - 1" name="chevron_right" color="grey-5" size="18px" />
            </template>
            <q-separator vertical class="q-mx-sm" />
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
        </div>
      </q-card>

      <!-- Detail Content Grid -->
      <div class="row q-col-gutter-md">
        <!-- Main & Sidebar Columns -->
      </div>
    </div>
  </q-page>
</template>
```

### 4.3 Skeleton Detail Page Template
```vue
<template>
  <q-page class="q-pa-md">
    <div class="q-gutter-y-md">
      <!-- Detail Header Skeleton -->
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <q-skeleton type="text" width="80px" height="14px" class="q-mb-xs" />
          <q-skeleton type="text" width="260px" height="32px" />
        </div>
        <div class="col-auto row q-gutter-x-sm">
          <q-skeleton type="QBtn" width="90px" height="36px" />
          <q-skeleton type="QBtn" width="110px" height="36px" />
        </div>
      </section>

      <!-- Status Workflow Strip Skeleton -->
      <q-card flat bordered class="q-pa-sm">
        <div class="row items-center q-gutter-x-sm">
          <q-skeleton v-for="n in 4" :key="n" type="QBtn" width="100px" height="28px" />
        </div>
      </q-card>

      <!-- 2-Column Content Grid Skeleton -->
      <div class="row q-col-gutter-md">
        <div class="col-12 col-md-8 q-gutter-y-md">
          <q-card flat bordered class="q-pa-md">
            <q-skeleton type="text" width="140px" height="22px" class="q-mb-md" />
            <div v-for="i in 4" :key="i" class="row justify-between q-mb-sm">
              <q-skeleton type="text" width="30%" />
              <q-skeleton type="text" width="40%" />
            </div>
          </q-card>
        </div>
        <div class="col-12 col-md-4 q-gutter-y-md">
          <q-card flat bordered class="q-pa-md">
            <q-skeleton type="text" width="100px" height="22px" class="q-mb-md" />
            <q-skeleton type="rect" height="100px" class="rounded-borders q-mb-sm" />
            <q-skeleton type="text" width="80%" />
          </q-card>
        </div>
      </div>
    </div>
  </q-page>
</template>
```

---

## 5. Data Table Skeleton Pattern

Use inside `<q-table>` loading slot or as standalone table skeleton markup.

```vue
<q-markup-table flat bordered class="treasury-table-wrap">
  <thead>
    <tr>
      <th style="width: 40px"><q-skeleton type="QCheckbox" /></th>
      <th><q-skeleton type="text" width="80px" /></th>
      <th><q-skeleton type="text" width="120px" /></th>
      <th><q-skeleton type="text" width="60px" /></th>
      <th class="text-right"><q-skeleton type="text" width="70px" /></th>
    </tr>
  </thead>
  <tbody>
    <tr v-for="n in 5" :key="n">
      <td><q-skeleton type="QCheckbox" /></td>
      <td><q-skeleton type="text" width="90%" /></td>
      <td><q-skeleton type="text" width="70%" /></td>
      <td><q-skeleton type="QBadge" width="50px" /></td>
      <td class="text-right"><q-skeleton type="text" width="60px" class="q-ml-auto" /></td>
    </tr>
  </tbody>
</q-markup-table>
```

---

## 6. Verification Checklist (PR Reject Criteria)

- [ ] `class="q-pa-md"` on `q-page` with `max-width: 1200px`
- [ ] `class="q-gutter-y-md"` for vertical page stack
- [ ] Header overline = `text-overline text-primary`, title = `h1.text-h5.text-weight-bold.q-my-none`
- [ ] Primary CTA = `unelevated no-caps` (no `round` / `pill-btn`)
- [ ] Toolbar card = `q-card flat bordered class="q-pa-sm"`
- [ ] Detail lifecycle status = Workflow button strip (not chip menu dropdown)
- [ ] Skeletons mirror exact loaded layout heights, padding, and gutter structure (Zero CLS)
- [ ] Skeleton loaders extracted into separate dedicated components (not inlined in page SFC)
- [ ] Repeating skeleton items use `v-for` loops
- [ ] No `AppPageHeader`, no hero title card, no un-nested floating search controls
