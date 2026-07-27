# UI Modernization & Performance Guide

This guide outlines standards and best practices for modernizing user interfaces across the application while ensuring **zero layout disruption, subtle high-end styling, and maximum rendering performance**.

---

## 🛑 MANDATORY RULE: Zero Component Rearrangement

> [!IMPORTANT]
> **1. Preserve Component Placement**: Modernization MUST NOT alter, move, or scramble the placement or layout ordering of existing components on a page. Keep every element in its established position.
> **2. Subtle & Premium Polish**: Modernization must be achieved through **subtle styling refinements** (refined border tokens, soft dynamic shadows, subtle active/hover states, crisp antialiased typography, soft-tint status chips) to deliver a sleek, React-like SaaS aesthetic without changing component positions or breaking user mental models.

---

## ⚡ Core Philosophy: Aesthetics Without Lag

A great user interface must look sleek and modern **without sacrificing rendering speed**. 

- **Aesthetics**: Clean visual hierarchy, subtle micro-interactions, soft-tint badges, rounded corners (`8px` to `12px`), and subtle hover states.
- **Performance**: Zero heavy CSS filters, zero layout reflow animations, minimal DOM node overhead, and strict pagination/virtualization for large datasets.

---

## 🚫 Performance & Styling Rules

To keep the application fast and responsive across all devices:

| ❌ What NOT To Do | ✅ What To Do Instead | Why |
| :--- | :--- | :--- |
| **Rearranging/moving page components** | Keep components in exact current placement; apply subtle CSS polish | Preserves existing layout structure and user workflows. |
| **`backdrop-filter: blur()`** | Solid semi-transparent background (`rgba(15, 23, 42, 0.4)`) | Prevents costly GPU layer recomposition on every scroll frame. |
| **Animating `height`, `width`, or `margin`** | Animating `transform: translateY()` and `opacity` | Runs on GPU compositor thread without triggering layout reflows. |
| **Rendering 100+ unpaginated table rows** | Quasar pagination (`pagination.rowsPerPage`) or virtual scrolling | Keeps DOM node count low, preventing memory bloat and latency. |
| **Inline style objects (`:style="{ ... }"`)** | SCSS utility classes in `app.scss` | Avoids Vue re-evaluating style objects on every render cycle. |

---

## 🎨 Subtle Refinement Blueprint (Preserving Placement)

### 1. Page Header Standards

> [!NOTE]  
> Refer strictly to [PAGE_HEADER.md](file:///Users/daviditc/Documents/Personal%20Project/brandwala-wholesale-quasar-v2/docs/PAGE_HEADER.md) for all page header structures, eyebrow rules, title sizing, and action button styles. Do not alter header button order or placement.

---

### 2. Modernizing Cards & Containers in Place

Without moving cards or sections, upgrade their visual container styles:

```vue
<!-- BEFORE: Heavy material card -->
<q-card class="q-pa-md shadow-2"> ... </q-card>

<!-- AFTER: Subtle, sleek container in exact same place -->
<q-card flat bordered class="card-hover"> ... </q-card>
```

---

### 3. Lightweight Inputs & Search Bars

Keep inputs in their current position, styled with `outlined` and `dense` props for a clean, non-intrusive look:

```vue
<q-input
  v-model="searchQuery"
  outlined
  dense
  placeholder="Search items..."
  class="toolbar-search"
>
  <template #prepend>
    <q-icon name="ph ph-magnifying-glass" size="18px" class="text-grey-6" />
  </template>
</q-input>
```

---

### 4. Hardware-Accelerated Micro-Interactions

Apply subtle hover transitions to existing interactive elements:

```css
/* ✅ Fast, Subtle & GPU-Accelerated */
.card-hover {
  transition: transform 0.15s ease, box-shadow 0.15s ease;
}

.card-hover:hover {
  transform: translateY(-2px);
  box-shadow: var(--bw-theme-shadow);
}
```

---

### 5. Soft-Tint Badges (`.square-chip` / `.entry-status-chip`)

Replace solid/harsh status blocks with lightweight soft-tinted tags without shifting layout:

```vue
<!-- Lightweight Soft Chip -->
<span class="square-chip">DRAFT</span>

<!-- Status Indicator Badge -->
<span class="entry-status-chip entry-status-chip--paid">
  <span class="status-dot bg-positive"></span>
  Completed
</span>
```

---

## ⚡ Verification Checklist

Before completing any UI refinement task:

1. **Placement Audit**: Verify all page buttons, inputs, headers, and cards are in their exact original locations.
2. **Scroll Performance**: Ensure scrolling on data-heavy tables remains locked at 60fps.
3. **Responsive Scaling**: Layout collapses cleanly from desktop monitors (`1200px+`) down to mobile screens (`320px`).
4. **Dark Mode Alignment**: Zero hardcoded hex colors in local `.vue` components; all colors pull from `--bw-theme-*` variables.
