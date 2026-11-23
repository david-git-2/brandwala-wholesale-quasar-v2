---
name: quasar
description: Guide for creating premium, high-performance, responsive, accessible, and theme-consistent Quasar (Vue 3) interfaces for TradeFlow BD.
---

# Quasar UI skill (thin)

**Canon:** `.cursor/rules/quasar-ui.mdc` — read that first. Do not re-open superseded UI rule files.

**New ops list:** copy `docs/guides/OpsListPage.skeleton.vue`. Never open `InboundShipmentListPage.vue` for chrome.

**Token tables / dense columns:** `docs/guides/ui-standards.md` — grep the section you need; do not full-read.

## Must use

- Tokens: `--tf-*` only (never `--bw-*`).
- Shared: `TfBtn`, `TfStatusBadge`, `TfSideSheet`, `TfDrawerSectionTabs*`, `TfEmptyState`, `TfSkeletonRows`, `TfEntityListShell` / `TfEntityListRow`.
- Feedback: `appFeedback.ts` / `useNotify()` — never raw `Notify.create` / `Dialog.create`.
- Icons: `ph ph-*`.

## Performance

- Lists >50 rows: pagination or virtual scroll.
- Search inputs: `debounce="300"`.
- Prefer skeletons over spinners for first paint.

## Mobile / a11y

- Icon-only actions: `aria-label` + `q-tooltip`.
- Touch CTAs (shop): `TfBtn` `size="lg"` / `shopCta` when needed.
- `data-test` on primary actions and key rows.
