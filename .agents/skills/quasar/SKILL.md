---
name: quasar
description: Guide for creating premium, high-performance, responsive, accessible, and theme-consistent Quasar (Vue 3) interfaces for Brandwala.
---

# Quasar Framework UI & Performance Best Practices

Guide for designing, building, styling, and optimizing Vue 3 components using the Quasar Framework in Brandwala.

## Core Principles

1. **Aesthetic Polish & Tokens:** Maintain visual excellence using exact CSS theme tokens (`--bw-theme-*`) from [UI_CONSISTENCY.md](file:///Users/daviditc/Documents/Personal%20Project/brandwala-wholesale-quasar-v2/docs/UI_CONSISTENCY.md). Avoid hardcoded hex/RGB colors.
2. **High Performance:** Optimize list virtualization, asset loading, reactivity overhead, and input debouncing.
3. **Responsive & Mobile-First:** Fluid layouts, adaptive dialogs/sheets, touch gesture support, and safe-area compliance.
4. **Accessibility & Testability:** Include ARIA labels on icon buttons, keyboard shortcuts, high contrast ratios, and explicit `data-test` attributes.

---

## 1. Theme Tokens & Sizing Rules

### Theme Scopes
- `.theme-platform` (Teracotta/Amethyst - Platform level)
- `.theme-app` (Emerald - Merchant app/desk)
- `.theme-shop` (Sapphire - Customer shop)
- `.theme-investor` (Teal - Finance desk)

### Key CSS Theme Variables
`--bw-theme-base`, `--bw-theme-surface`, `--bw-theme-border`, `--bw-theme-ink`, `--bw-theme-muted`, `--bw-theme-primary`, `--bw-theme-primary-soft`, `--bw-theme-shadow`.

### Radius Rules
- **Buttons (`q-btn`):** `8px`
- **Inputs & Rich Editors (`.soft-input`):** `8px`–`10px`
- **Metrics / Stat Cards (`.stat-card`):** `10px`
- **Floating Surfaces & Empty States:** `14px`
- **Heros & Banners:** `16px`
- **Pills / Status Badges:** `999px`

---

## 2. Page Structure & Layout Patterns

```vue
<template>
  <q-page class="bw-page">
    <div class="bw-page__stack">
      <!-- Header -->
      <app-page-header title="Page Title" subtitle="Subtitle description" eyebrow="SECTION">
        <template #actions>
          <q-btn
            label="Create New"
            icon="add"
            color="primary"
            unelevated
            :loading="isSaving"
            @click="handleCreate"
            data-test="create-btn"
          />
        </template>
      </app-page-header>

      <!-- Main Card -->
      <q-card flat bordered class="form-card">
        <q-card-section>
          <!-- Content -->
        </q-card-section>
      </q-card>
    </div>
  </q-page>
</template>
```

### Core Utility Classes
- `.bw-page`: Responsive padding (`clamp(1rem, 2.4vw, 2rem)`).
- `.bw-page__stack`: Vertical grid stack (`gap: 1.25rem`).
- `.bw-entity-grid`: Grid listing (`repeat(auto-fit, minmax(240px, 1fr))`, `gap: 1rem`).
- `.bw-inline-actions`: Action button row (`gap: 0.65rem`).

---

## 3. Performance & Rendering Optimization

1. **Virtual Scrolling & Tables:** Use `<q-virtual-scroll>` or server-side pagination on `<q-table>` for lists exceeding 50 items.
2. **Input Debouncing:** Add `debounce="300"` on search and filter `<q-input>` components.
3. **Asset & Image Lazy Loading:** Use `<q-img>` with ratios, WebP formats, and skeleton loading slots (`<template #loading><q-skeleton /></template>`).
4. **Reactivity Management:** Use `shallowRef()` for large immutable objects and `v-memo` / `v-once` for static row render lists.
5. **Icon Optimization:** Prefer explicit SVG icon imports over bundling entire webfont packages.

---

## 4. Component Recipes & UX Polish

### 4.1 Buttons
* **Primary CTA:** `q-btn color="primary" unelevated` (Max 1 per header).
* **Secondary:** `q-btn flat` or `q-btn outline`.
* **Danger:** `q-btn color="negative" unelevated` or `flat color="negative"`.
* **Icon-Only:** `flat round` with `aria-label="..."` and a nested `<q-tooltip>`.
* **Async Feedback:** Always bind `:loading="loadingState"` and `:disable="loadingState"`.

### 4.2 Forms & Validation
* Use `outlined` and `dense` props on inputs for a lightweight aesthetic.
* Bind `:error` and `:error-message` for inline validation feedback.
* Leverage Quasar input masks (`mask="..."`) or `date.formatDate` utilities instead of custom formatting logic.

### 4.3 Tables
* Wrap `q-table` in `.treasury-table-wrap` (or `<treasury-table-wrap>`) for containerized horizontal scrolling.
* Use dense typography (`11px` to `13px`) for complex data grids.

### 4.4 Lift-on-Hover Card Interaction
```css
.card-hover {
  transition: transform 0.2s cubic-bezier(0.4, 0, 0.2, 1), box-shadow 0.2s ease;
  &:hover {
    transform: translateY(-2px);
    box-shadow: var(--bw-theme-shadow);
  }
}
```

---

## 5. Centralized Feedback & Dialogs

**NEVER** call `Notify.create` or `Dialog.create` directly. Use standardized wrappers from [appFeedback.ts](file:///Users/daviditc/Documents/Personal%20Project/brandwala-wholesale-quasar-v2/web/src/utils/appFeedback.ts):

```typescript
import {
  showSuccessNotification,
  showErrorNotification,
  requestConfirmation,
  handleApiFailure
} from 'src/utils/appFeedback';

showSuccessNotification('Item saved');
const confirmed = await requestConfirmation('Delete item?', 'Confirm', 'Delete');
if (confirmed) {
  // perform action
}
```

---

## 6. Mobile, Accessibility & Testing Standards

* **Adaptive Layouts:** Render modals as centered `<q-dialog>` on desktop and bottom sheets on mobile screens (`$q.screen.lt.sm`).
* **Accessibility:** Enforce keyboard accessibility (`@keyup.enter` submit handlers) and ARIA attributes on non-text buttons.
* **E2E & Testability:** Include `data-test="<action-name>"` attributes on form controls, action buttons, and table rows.
