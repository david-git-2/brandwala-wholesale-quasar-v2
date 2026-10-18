# Perf and UX next steps (backlog)

Suggestions after the Phase 1-5 work. Not product truth, not as-built. Baseline numbers: [2026-10-18-perf-baseline.md](2026-10-18-perf-baseline.md). Ideas below are unverified in code unless noted.

## Done so far

| Phase | Result |
| :--- | :--- |
| 1 Measure | Bundle report, top chunks, firebase and chart.js not in entry. Lighthouse and slow-query tables filled by hand. |
| 2 First load | CSS split (857 KiB to 281 KiB first load), vendor chunks, material-icons removed. |
| 3 Requests | `src/query/staleTimes.ts`. `select('*')` left alone (small queries). |
| 4 Database | Notification RLS uses `(select auth.uid())`. No slow app query found. |
| 5 Screens | No change. Lists already paginate, search already debounced. |

## Architecture

| # | Item | Why | Effort |
| :--- | :--- | :--- | :--- |
| A1 | Real-user monitoring: Web Vitals (LCP, INP) plus an error tracker | Shows which page is slow for real users | S |
| A2 | CI on every push: `type-check`, lint, `build` | A missing file broke the build; type-check hits the memory limit | S |
| A3 | Keep dev doc, Mermaid and design-system pages out of the production build (~3 MB JS) | Smaller deploy, fewer files | S |
| A4 | Done: scraper JSON moved from `web/public/uk` to `python/data/uk/out` (git-ignored, not in the web build). Old copies stay in git history. | Smaller repo growth | S |
| A5 | Convert dashboard background images (350-480 KB each) to WebP or AVIF, resize, lazy-load | About 2 MB saved | S |
| A6 | Phosphor: ship WOFF only, or subset the icons / use an SVG sprite (SVG font is 2.9 MB) | Check which font file the CSS loads | S |
| A7 | Supabase Realtime on stock, demand, orders; then raise `staleTime` | Fresh data without refetch | M |
| A8 | Service worker for the app shell; persist Vue Query cache to IndexedDB | Fast repeat visits, weak networks | M |
| A9 | Run product sync (117k rows) off-peak, in small batches | Shares the DB with users | M |
| A10 | One RPC per heavy screen (check dashboard) | Fewer round trips | M |
| A11 | Automated tests: a user of tenant A cannot read tenant B rows (296 RLS policies) | Cheap guard against the worst bug | M |

## Product and design

| # | Item | Why |
| :--- | :--- | :--- |
| P1 | Skeleton loaders, optimistic updates, `keepPreviousData` on filter change | Feels faster at the same speed |
| P2 | List 3 daily tasks per role; aim for 2 clicks or fewer; add Cmd+K search | Speeds up staff work |
| P3 | Test the shop on slow 4G and a mid-range Android phone | Shop customers are likely on phones |
| P4 | Clear empty, error and offline states with a retry button; keep failed form data | Less frustration |
| P5 | Progressive disclosure on dense pages (procurement demand, costing) | Fewer choices per screen |
| P6 | Finish moving old pages to `Tf*` components and color tokens (`check:ui-colors`) | Consistent UI, shared CSS |
| P7 | Tooltips, first-run hints, doc links on complex pages | Fewer support questions |
| P8 | Accessibility: keyboard order, dialog focus, labels on icon-only buttons | Contrast already passes |
| P9 | Notification preferences and grouping | Avoid alert fatigue |
| P10 | Bangla fonts and number formats; easy language switch | If users prefer Bangla |

Effort: S = about a day, M = several days.

## Pick first

1. A1 monitoring and error tracking.
2. A5 and A4 image and data compression.
3. A2 CI and A11 cross-tenant RLS tests.

## Open items from earlier phases

| Item | Needs |
| :--- | :--- |
| Lighthouse scores (dashboard, shop orders, procurement demand) | Run signed in, fill the baseline doc |
| Cloudflare upload with 744 files after CSS split | Deploy once; if it fails set `cssCodeSplit: false` in `web/quasar.config.ts` |
| Toast icons (Phosphor) | Open one success and one error toast |
| `shopPricingRepository.ts` products fetch (up to 100 rows, `select('*')`) | Decide which columns the page uses |
| Boot file order in `quasar.config.ts` | Test login flow before reordering |
