---
name: quasar
description: Guide for creating premium, high-quality, and highly responsive user interfaces using Quasar Framework (Vue 3) matching Brandwala's design tokens and theme.
---

# Quasar Framework UI Best Practices

This skill guides the design, implementation, styling, and optimization of Vue 3 components using the Quasar Framework, ensuring consistent, responsive, accessible, and premium interfaces.

## When to Apply

Use this skill when:
- Designing or modifying Vue 3 files (`.vue`) in the frontend.
- Adding, refactoring, or styling Quasar components (`q-card`, `q-btn`, `q-input`, `q-table`, etc.).
- Defining layout styles, custom utilities, page flows, or theme states.
- Integrating user feedback mechanisms (toasts, alerts, confirmation dialogs).

## Core Principles

1. **Aesthetic Excellence & Visual Polish**
   - Interfaces should feel premium. Avoid basic default styles and plain shapes. Use subtle hover states, smooth transitions, correct border radii, and soft shadows.
   - Implement micro-interactions (e.g., subtle translate/scale effects on cards, icon morphing).

2. **Strict Consistency with UI Tokens**
   - Align exactly with the definitions in [UI_CONSISTENCY.md](file:///Users/daviditc/Documents/Personal%20Project/brandwala-wholesale-quasar-v2/docs/UI_CONSISTENCY.md). Do not invent ad-hoc colors or custom utility classes when standard ones exist.

3. **Seamless Dark Mode Support**
   - **Never** hardcode hex colors or RGB values (e.g., `#ffffff`, `rgba(0,0,0,0.1)`) directly in component styles.
   - Use custom theme CSS variables (`--bw-theme-*`) and brand CSS variables (`--bw-brand-*`) to guarantee high visual quality in both Light and Dark modes.

4. **Responsive-First Layouts**
   - Layouts must adjust gracefully from small screens (320px) to large desktop monitors (1200px+).
   - Use `col-xs-12 col-md-8` style responsive grid wrappers and flex classes instead of fixed dimensions.

---

## 1. Color, Spacing & Sizing Tokens

Ensure the following variables are utilized rather than standard defaults:

### Theme Scopes
The app applies color schemas based on the active module section via classes:
- `.theme-platform` (Teracotta/Deep Imperial Amethyst - Platform level)
- `.theme-app` (Premium Emerald - Merchant app/desk views)
- `.theme-shop` (Luxury Sapphire - Customer shop/ordering)
- `.theme-investor` (Teal - Finance/investor desk)

### CSS Theme Variables
Always pull color and styling definitions from:
- `--bw-theme-base` (Main background)
- `--bw-theme-surface` (Card/component surface background)
- `--bw-theme-border` (Borders/dividers)
- `--bw-theme-ink` (Body text)
- `--bw-theme-muted` (Muted/secondary labels)
- `--bw-theme-primary` / `--q-primary` (Primary brand accent)
- `--bw-theme-primary-soft` (Subtle tinted backgrounds for active states or tags)
- `--bw-theme-shadow` (Soft dynamic container shadow)

### Key Radius Guidelines
| UI Element | Class/Style Rule |
| :--- | :--- |
| **Buttons** (`q-btn`) | `8px` (predefined globally in CSS) |
| **Form Inputs & Rich Editors** | `8px` to `10px` (`.soft-input`) |
| **Simple Metrics & Stat Cards** | `10px` (`.stat-card`) |
| **Floating Surfaces & Empty States** | `14px` (`.floating-surface`, `.empty-state-block`) |
| **Large Heros & Banners** | `16px` (`.hero-surface`) |
| **Pills / Status Badges** | `999px` (`.pill-btn`, default chips) |

---

## 2. Page & Layout Flow Patterns

All standard page layouts should follow this structural blueprint:

```vue
<template>
  <q-page class="bw-page">
    <div class="bw-page__stack">
      <!-- Page Header -->
      <app-page-header
        title="Page Title"
        subtitle="A helpful subtitle describing the page context"
        eyebrow="MODULE SECTION NAME"
      >
        <template #actions>
          <q-btn
            label="Create New"
            icon="add"
            color="primary"
            unelevated
            @click="openCreateDialog"
          />
        </template>
      </app-page-header>

      <!-- Page Content: Cards, Grid list or Tables -->
      <q-card flat bordered class="form-card">
        <q-card-section>
          <!-- Content goes here -->
        </q-card-section>
      </q-card>
    </div>
  </q-page>
</template>
```

### Core Layout Classes
- `.bw-page`: Clamp-based padding (`padding: clamp(1rem, 2.4vw, 2rem)`) that adjusts from mobile to desktop.
- `.bw-page__stack`: Grid stack with `gap: 1.25rem` spacing between sections.
- `.bw-entity-grid`: Responsive card list using CSS grid (`grid-template-columns: repeat(auto-fit, minmax(240px, 1fr))`, `gap: 1rem`).
- `.bw-inline-actions`: Action button list with flex wrap and `gap: 0.65rem`.

---

## 3. Best Practice Component Recipes

### 3.1 Buttons
Use the following configurations:
* **Primary CTA:** `q-btn color="primary" unelevated` (Max 1 per header block).
* **Secondary / Quiet Actions:** `q-btn flat` or `q-btn outline`.
* **Danger/Destructive:** `q-btn color="negative" unelevated` or `flat color="negative"`.
* **Icon buttons:** `flat round` with an nested `q-tooltip` for context.
* **Density adjustments:** Use `.slim-btn` for high density layout rows (32px tall).

### 3.2 Forms & Inputs
* Always prefer `outlined` and `dense` props on `q-input`, `q-select`, `q-checkbox` to look modern, lightweight, and clean.
* Set fields to `:error` and use `:error-message` props for inline validation feedback.
* Avoid custom shadows on inputs unless explicitly defining `.soft-input` variants.

### 3.3 Tables
* Wrap all `q-table` components in `.treasury-table-wrap` (or use `<treasury-table-wrap>`) to allow clean horizontal scrolling without breaking the layout.
* For dense operations (e.g. logistics/shipment detail tables), keep text size small (`11px` to `13px`) using appropriate classes or CSS targets.

### 3.4 Premium Interactions: Lift-on-hover card
To make list items or selectable cards feel premium, add `.card-hover`:
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

## 4. Notifications, Dialogs & Feedback

**NEVER** call `Notify.create` or `Dialog.create` directly in modules. Instead, import and use the standard wrappers defined in [appFeedback.ts](file:///Users/daviditc/Documents/Personal%20Project/brandwala-wholesale-quasar-v2/web/src/utils/appFeedback.ts):

```typescript
import {
  showSuccessNotification,
  showErrorNotification,
  showWarningNotification,
  showWarningDialog,
  requestConfirmation,
  handleApiFailure
} from 'src/utils/appFeedback';

// To display a success toast
showSuccessNotification('Item saved successfully');

// To confirm a destructive action
const confirmed = await requestConfirmation(
  'Are you sure you want to delete this invoice?',
  'Delete Invoice',
  'Delete'
);
if (confirmed) {
  // delete item
}
```
