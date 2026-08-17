# Help — deferred plan

**Status:** spec only. Do not implement until a dedicated Help pass. Do not add module guides, portal content, or `LearnMoreHelpBtn` under the old model.

Canon for guidance layers: [docs/UI_CONSISTENCY.md](../docs/UI_CONSISTENCY.md). Page rule: `.cursor/rules/frictionless-ui.mdc`.

---

## 1. What it is

Help is **recovery on the screen the staff is already on**.

| Layer | Audience | Job |
|---|---|---|
| **The page** | Staff | Primary teacher: one-line “what this is” + one next action. Happy path never needs Help. |
| **Help (`?` drawer)** | Same staff, when stuck | 3–8 blockers that match **real buttons** on that page. |
| **`doc/`** | Developers / agents | How to build it. Never a staff manual. |

One surface: the header **`?` drawer**, resolved from the current route.

Not Help:

- A `/help` portal, module card grid, or searchable textbook
- A per-nav-group “what each page does” landing
- Onboarding, product tours, or Help-drawer essays dumped onto the page
- In-app Documentation (`/app/documentation`) — that is a spec dump for builders; retire it separately, do not replace it with Help

---

## 2. Why

The current Help Center is unused because it is the wrong job.

| Today | Problem |
|---|---|
| `/platform/help`, `/:slug/app/help`, shop/investor copies | Destination. Staff in Shipments never go there. |
| Module guides (Overview / Workflows / Key Terms / FAQs) | Textbooks. They rot; they do not answer “why is this button off?” |
| Coverage gaps (no procurement, invoices, treasury) | Proves the encyclopedia does not scale. |
| Captions already on nav routes, hidden in the sidebar | Orientation belongs on the page and the nav, not in Help. |
| `docs/OPTIMIZE_HELP_CENTER.md` + registry essays | Taught agents to fill the textbook. Removed. |

Staff skip maps. They open Help when a control is disabled or the next step is unclear. That is the only moment worth writing for.

---

## 3. Target UX (when implemented)

1. Staff are on a working page (list or detail).
2. Header `?` opens a right drawer for **this page**.
3. Drawer lists blockers only — questions in shop-floor English, answers that name the same labels as the UI.
4. If the page has no blockers yet: empty state “This screen explains itself” — no Getting Started meta-guide.
5. Disabled primary actions still explain themselves on the page (`q-tooltip` / status banner). Help is backup, not the first teacher.

Do **not** add a Help Center nav item. Do **not** add group hub pages.

---

## 4. Data shape (replace `ModuleGuide`)

Keep TypeScript files. No CMS, no DB table, no vue-i18n for body copy.

**Today (retire):** `web/src/modules/help/types.ts` → `ModuleGuide` with `overview`, `workflows`, `terms`, `faqs`. Files under `web/src/modules/help/data/guides/`. Aggregator `moduleGuideRegistry.ts`.

**Target:** one file per **page family**, not per module.

```ts
type LocalizedText = { en: string; bn: string };

type PageHelp = {
  id: string;                    // kebab, stable
  title: LocalizedText;          // page name, not module name
  routeMatchers: string[];       // path substrings; longest hit wins
  scopes: Array<'platform' | 'app' | 'shop' | 'investor'>;
  audiences: Array<'superadmin' | 'admin' | 'staff' | 'viewer' | 'merchant' | 'investor'>;
  blockers: Array<{
    id: string;
    question: LocalizedText;     // "Why is Receive disabled?"
    answer: LocalizedText;       // names the real button / banner
  }>;
};
```

Rules:

- 3–8 blockers. If you cannot write three real blockers, the page is not ready for Help — fix the page subtitle / disabled-why first.
- Every `en` has a `bn`. UI chrome (drawer title, close) stays in vue-i18n.
- `routeMatchers` must hit the attached page URL. Prefer the most specific path.
- No Overview, Workflows, or Key Terms tabs.
- Do not invent RPC/table/ATP jargon in copy.

---

## 5. How to update data (Help pass only)

Do not run this until the drawer + `PageHelp` type exist. Until then, **do not add or rewrite guides**.

1. Attach the live `.vue` page (and the bar/dialog that owns the stuck action).
2. List real blockers from the UI: disabled CTAs, status gates, empty states people misread.
3. Upsert `web/src/modules/help/data/pages/<idCamel>.ts` as a `PageHelp` with both locales.
4. Register it in the aggregator (`moduleGuideRegistry.ts` or its replacement).
5. Set `routeMatchers` so `?` on that page opens this file.
6. Do not add `LearnMoreHelpBtn` unless the page has a status-gated action whose tooltip already points at Help.

Prompt shape:

```
Using doc/HELP_CENTER.md and @InboundShipmentDetailsPage.vue,
add app/staff blockers for Receive / In transit.
id: inbound-shipment-details
```

Do **not** port old module guides. Rewrite from the page. Delete unused `data/guides/*.ts` in the same pass.

---

## 6. Implementation order (later)

| ID | Change | Notes |
|---|---|---|
| **H0** | Freeze | This doc. No new guides, no portal polish, no Learn-more buttons. |
| **H1** | Types + registry | `PageHelp` + `data/pages/`. Stop resolving `ModuleGuide`. |
| **H2** | Drawer only | Rewrite `ModuleHelpDrawer.vue` to blockers. Remove `HelpCenterPage.vue`, help routes, Help Center nav links in `useWorkspaceNavigation.ts`. |
| **H3** | Content cutover | Delete `data/guides/*`. Add blockers only for pages touched in that pass. Empty drawer is valid. |
| **H4** | Cleanup | Drop `HelpTab`, search, locale-on-portal, `helpCenterPathForScope`. Keep `en`/`bn` toggle on the drawer. |

In-app Documentation retirement is **not** H4. Track it on the documentation module when you kill `/app/documentation`.

---

## 7. Out of scope

- Per-nav-group explainer pages
- Product tours / coach marks
- Backend or CMS for help articles
- Filling every module before the drawer works
- Sending staff to `doc/*.md` or `/app/documentation`
- Using Help as onboarding

---

## 8. Legacy dropped (this change)

| Removed | Why |
|---|---|
| Previous `doc/HELP_CENTER.md` (module encyclopedia + Phases 0–4 portal) | Specified the unused product |
| `docs/OPTIMIZE_HELP_CENTER.md` | Taught agents to write textbooks |

Code under `web/src/modules/help/` stays until H1–H3. Do not expand it.
