# Component Modularization & Refactoring Guide

> **TL;DR Quick Rules for AI Agents & Developers:**
> 1. **Size Limit:** Max **300 lines** per `.vue` page. Max **150 lines** per sub-component.
> 2. **Rule of 3:** If a single file contains >3 distinct visual blocks (e.g. Header, Table, Summary, Modals), extract each block into `components/`.
> 3. **Fast Script Refactoring:** Do NOT immediately extract all logic to composables. Keep state in the parent page and pass it down via props. Only extract to `composables/` if the logic is shared or the parent script alone exceeds 150 lines.
> 4. **Parent is Container:** Parent page handles routes, query calls, layout grid, and holds primary state.
> 5. **Token Efficiency:** Editing 100-line components costs ~87% fewer context tokens and runs 4x faster.

---

## 📏 Size & Responsibilities Reference

| File Type | Location | Target Lines | Max Lines | Responsibilities |
| :--- | :--- | :--- | :--- | :--- |
| **Parent Page** | `pages/[PageName].vue` | **150 – 180** | **250** | Route orchestrator, TanStack Query calls, layout grid |
| **Sub-Component** | `components/[PagePrefix][Section].vue` | **80 – 150** | **200** | Visual presentational block, explicit `defineProps` & `defineEmits` |
| **Composable** | `composables/use[Feature].ts` | **50 – 120** | **180** | Pure business math, reactive refs, formatting utilities |

---

## 🤖 AI Agent Mega-File Protocol (For Files > 800 Lines)

When an AI Agent is tasked with refactoring massive files (e.g., 1500+ lines like `ThriftStockPage.vue`), it will struggle with context limits, timeouts, and hallucinations if it attempts to do too much at once. 

**AI Agents MUST follow these strict rules for massive files:**

1. **One Component Per Turn:** NEVER attempt to extract multiple sub-components in a single tool call or single prompt response. Extract exactly **ONE** visual block (e.g., just the Table, or just the Dialog), wire it up, verify it, and stop. Wait for the next step.
2. **Surgical Parent Edits:** Do NOT attempt to rewrite or replace the entire parent file. Use the `multi_replace_file_content` tool with precise `StartLine` and `EndLine` constraints to surgically remove the extracted HTML and insert the child component tag.
3. **Prop & Emit Grouping:** If a child component requires 10+ props and 10+ emits, do not panic. Write them out explicitly in the child, but do it carefully. To save tokens, avoid refactoring the parent's state—just pass the existing refs directly as props.
4. **Leave Unrelated Script Alone:** When extracting a UI template, leave the rest of the parent's `<script setup>` completely untouched. Do not reformat or optimize unrelated functions during a component extraction.

---

## ⚡ 4-Step Fast-Track Refactoring Checklist

*Note: Untangling reactivity into composables is time-consuming. To refactor fast, focus on UI template extraction first.*

```mermaid
graph TD
    A["1. Detect File > 300 Lines"] --> B["2. Extract Visual Blocks to components/"]
    B --> C["3. Pass State via Props/Emits"]
    C --> D["4. Assemble in Parent Page"]
    D --> E["5. Run vue-tsc & eslint"]
```

- [ ] **Step 1: Audit Boundaries** — Identify visual sections (Header, Items Table, Financial Summary, Shipping Card, Modals).
- [ ] **Step 2: Build Sub-Components** — Create `components/[PagePrefix][Section].vue`. Move ONLY the template HTML and scoped CSS. 
- [ ] **Step 3: Quick Wiring** — Define explicit `defineProps` & `defineEmits` in the child. Keep the complex state, API calls, and logic in the parent page.
- [ ] **Step 4: Connect Parent** — Replace template sections in `pages/[PageName].vue` with child components. Run `npx vue-tsc --noEmit` and `npx eslint src/modules/[module]/`.

*(Optional Step 5): Only extract non-UI calculations, refs, and watch blocks to `composables/use[Feature].ts` if the parent `<script setup>` is still too bloated (>150 lines).*

---

## 📂 Standard File Structure Pattern

```text
src/modules/[module_name]/
├── pages/
│   └── CustomerOrderDetailPage.vue       (Container Page: ~170 lines)
├── components/
│   ├── CustomerOrderHeader.vue           (Header & Status chips: ~160 lines)
│   ├── CustomerOrderItemsList.vue        (Items list & Counter form: ~160 lines)
│   ├── CustomerOrderSummaryCard.vue      (Pricing summary & profit math: ~165 lines)
│   └── CustomerOrderShippingCard.vue     (Shipping details: ~50 lines)
└── composables/
    └── useShopOrderDetailQuery.ts        (TanStack Query composable: ~80 lines)
```

---

## 💻 Compact Code Template

### 1. Child Component (`components/CustomerOrderShippingCard.vue`)
```vue
<script setup lang="ts">
defineProps<{ order: any }>();
</script>

<template>
  <q-card flat bordered class="details-card">
    <q-card-section class="q-px-lg q-py-md text-body2 text-grey-8">
      <div class="text-weight-bold text-grey-9">{{ order.recipient_name }}</div>
      <div>{{ order.recipient_phone }}</div>
      <div class="q-mt-sm text-grey-6 bg-grey-1 q-pa-sm rounded-borders">{{ order.shipping_address }}</div>
    </q-card-section>
  </q-card>
</template>

<style scoped>
.details-card { border-radius: 14px; background: #fff; }
</style>
```

### 2. Parent Container (`pages/CustomerOrderDetailPage.vue`)
```vue
<script setup lang="ts">
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import { useShopOrderDetailQuery } from '../composables/useShopOrderDetailQuery';
import CustomerOrderHeader from '../components/CustomerOrderHeader.vue';
import CustomerOrderSummaryCard from '../components/CustomerOrderSummaryCard.vue';
import CustomerOrderShippingCard from '../components/CustomerOrderShippingCard.vue';

const route = useRoute();
const orderId = computed(() => Number(route.params.id || 0));
const { data: orderDetailsData, isLoading } = useShopOrderDetailQuery(orderId);
const currentOrder = computed(() => orderDetailsData.value?.order || null);
</script>

<template>
  <q-page class="q-pa-md">
    <q-spinner v-if="isLoading" color="primary" size="40px" />
    <div v-else-if="currentOrder" class="bw-page__stack">
      <CustomerOrderHeader :order="currentOrder" />
      <div class="row q-col-gutter-lg">
        <div class="col-xs-12 col-md-4">
          <CustomerOrderSummaryCard :order="currentOrder" />
          <CustomerOrderShippingCard :order="currentOrder" />
        </div>
      </div>
    </div>
  </q-page>
</template>
```

---

## 📊 Token & Performance Comparison

| Metric | Monolithic 700-line File | Modular 150-line File | Advantage |
| :--- | :--- | :--- | :--- |
| **Context Window Consumption** | ~12,500 tokens / request | ~1,600 tokens / request | **87% Token Savings** |
| **AI Processing Speed** | ~45 seconds / edit | ~10 seconds / edit | **4.5x Faster Execution** |
| **Bug Risk & Side Effects** | High (accidental edits to unrelated sections) | Low (isolated component contracts) | **Zero Regression** |
