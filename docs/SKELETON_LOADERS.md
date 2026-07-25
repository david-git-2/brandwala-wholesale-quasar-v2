# Skeleton Loaders Guide (Quasar Vue 3)

Quick-reference document for implementing modern, minimal-token skeleton loaders (`q-skeleton`) across Quasar pages and components in the Brandwala codebase.

---

## 1. Core Principles

1. **Zero Cumulative Layout Shift (CLS)**: Skeletons must mirror the exact layout structure, spacing (`q-gutter-y-md`), and heights of actual loaded content.
2. **Minimal Code & Tokens**: Use `v-for="n in 6"` for repeating items (cards, table rows) rather than duplicating markup blocks.
3. **Theme & Dark Mode Compatible**: `q-skeleton` natively uses Quasar CSS variables—never apply explicit custom background colors to skeleton elements.
4. **Prefer Skeletons over Full-Page Spinners**: Use `q-skeleton` for initial page content loads to maintain layout context. Reserve `QSpinner` for micro-actions (e.g., button loading states).

---

## 2. Element Mapping Cheat Sheet

| Component / UI Element | Quasar Skeleton Pattern | Dimensions / Class |
| :--- | :--- | :--- |
| **Page Title (`h1`)** | `<q-skeleton type="text" width="220px" height="32px" />` | Matches `h5` / `text-h5` line height |
| **Overline / Subtitle** | `<q-skeleton type="text" width="120px" height="14px" />` | Matches `text-overline` / `text-caption` |
| **Primary CTA Button** | `<q-skeleton type="QBtn" width="110px" height="36px" />` | Standard 36px CTA height |
| **Pill / Badge** | `<q-skeleton type="QBadge" width="80px" height="24px" />` | Status badge replacement |
| **Input / Search Field** | `<q-skeleton type="QInput" height="40px" />` | Standard dense field height |
| **Card / Surface Block** | `<q-card flat bordered class="q-pa-md"><q-skeleton type="rect" height="150px" class="rounded-borders" /></q-card>` | Matches container card radius |
| **Avatar / Profile** | `<q-skeleton type="QAvatar" size="40px" />` | Circular avatar |

---

## 3. Recommended Animation & Props

* **Default Animation**: Use `animation="wave"` for smooth, modern shimmer effects.
* **Border Radius**: Add `class="rounded-borders"` or match card corner styling (`border-radius: 8px`).

---

## 4. Copy-Paste Templates

### Template 1: List Page Skeleton Pattern

Use this structure when fetching paginated cards, grids, or list items.

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

      <!-- Toolbar / Filter Bar Skeleton -->
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

      <!-- Grid Content Skeleton (6 Items) -->
      <div v-if="loading" class="row q-col-gutter-md">
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

      <!-- Actual Loaded Content -->
      <div v-else class="row q-col-gutter-md">
        <!-- Loaded cards go here -->
      </div>
    </div>
  </q-page>
</template>
```

---

### Template 2: Detail Page Skeleton Pattern

Use this for detail pages (e.g. Order Details, Invoice Details, Product Details).

```vue
<template>
  <q-page class="q-pa-md">
    <div class="q-gutter-y-md">
      <!-- Loading State -->
      <template v-if="loading">
        <!-- Header -->
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

        <!-- 2-Column Content Grid -->
        <div class="row q-col-gutter-md">
          <!-- Main Left Column -->
          <div class="col-12 col-md-8 q-gutter-y-md">
            <q-card flat bordered class="q-pa-md">
              <q-skeleton type="text" width="140px" height="22px" class="q-mb-md" />
              <div v-for="i in 4" :key="i" class="row justify-between q-mb-sm">
                <q-skeleton type="text" width="30%" />
                <q-skeleton type="text" width="40%" />
              </div>
            </q-card>
          </div>

          <!-- Sidebar Right Column -->
          <div class="col-12 col-md-4 q-gutter-y-md">
            <q-card flat bordered class="q-pa-md">
              <q-skeleton type="text" width="100px" height="22px" class="q-mb-md" />
              <q-skeleton type="rect" height="100px" class="rounded-borders q-mb-sm" />
              <q-skeleton type="text" width="80%" />
            </q-card>
          </div>
        </div>
      </template>

      <!-- Loaded State -->
      <template v-else>
        <!-- Real Page Content -->
      </template>
    </div>
  </q-page>
</template>
```

---

### Template 3: Data Table Skeleton Pattern

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

## 5. MUSTs & MUST NOTs

### MUST
* **Use `v-for` loops** for repetitive list items, table rows, and status buttons.
* **Match exact widths/heights** of the target components (`36px` for CTA, `28px` for dense status chips, `14px` for captions).
* **Wrap custom table skeletons** in `.treasury-table-wrap` (or `<q-markup-table flat bordered>`) for consistent scroll & border behavior.

### MUST NOT
* **Do NOT hardcode CSS colors** on `<q-skeleton>` elements (let Quasar handle dark/light mode shading automatically).
* **Do NOT duplicate entire card sub-trees** manually—use `v-for="n in count"`.
* **Do NOT mix sizes** (e.g. using a 50px tall skeleton for a 32px text input).
