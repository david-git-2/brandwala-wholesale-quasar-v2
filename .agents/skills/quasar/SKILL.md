---
name: quasar
description: Guide for creating premium, high-performance, responsive, accessible, and theme-consistent Quasar (Vue 3) interfaces for TradeFlow BD.
---

# Quasar UI skill (thin)

**Canon:** `.cursor/rules/quasar-ui.mdc` — read that first.

**New ops list:** copy `docs/guides/OpsListPage.skeleton.vue`. Never open mega live list pages for chrome.

## Must use

- Tokens: `--tf-*` only.
- Shared: `TfBtn`, `TfStatusBadge`, `TfSideSheet`, `TfDrawerSectionTabs*`, `TfEmptyState`, `TfSkeletonRows`, `TfEntityListShell` / `TfEntityListRow`.
- Feedback: `appFeedback.ts` / `useNotify()`.
- Icons: `ph ph-*`.

## Performance

- Lists >50 rows: pagination or virtual scroll.
- Search: `debounce="300"`.
- Skeletons over spinners for first paint.

## Mobile / a11y

- Icon-only: `aria-label` + `q-tooltip`.
- Shop CTAs: `TfBtn` `size="lg"` / `shopCta` when needed.
- `data-test` on primary actions.
