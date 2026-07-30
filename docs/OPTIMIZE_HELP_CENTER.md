# Help Center Content Protocol (AI)

> **When to use:** Attach this doc + a page (or module folder) and ask to add/update Help for that screen.
> Example: `Using docs/OPTIMIZE_HELP_CENTER.md and @DropshipFinanceHubPage.vue, add staff help for remittance.`

## 1. What Help Center Is

- End-user guidance inside the app (not developer Markdown in `doc/`).
- Two surfaces, one content source:
  - Header **`?` Module Guide** drawer (contextual)
  - **Help Center** portal (`/platform/help`, `/:tenant/app/help`, `/:tenant/shop/help`, `/:tenant/investor/help`)
- Content lives in TypeScript: `web/src/modules/help/data/moduleGuideRegistry.ts`
- Shell access is all scopes; **guides are filtered by `scopes` + `audiences`**

## 2. Inputs

| Input | Required | Notes |
|-------|----------|--------|
| Attached `.vue` page (or key components) | Yes | Source of truth for workflows / blockers |
| Guide `id` | No | Reuse existing id when updating; invent kebab/`snake` id when new |
| Target `scopes` | Usually yes | `platform` \| `app` \| `shop` \| `investor` |
| Target `audiences` | Usually yes | `superadmin` \| `admin` \| `staff` \| `viewer` \| `merchant` \| `investor` |

Do **not** invent backend/CMS storage. Do **not** rewrite drawer/shell unless plumbing is broken.

## 3. Output contract (edit only these)

1. **`web/src/modules/help/data/moduleGuideRegistry.ts`**
   - Upsert a `ModuleGuide`: `overview`, `workflows`, `terms`, `faqs`, `routeMatchers`, `scopes`, `audiences`
2. **Optional:** add `LearnMoreHelpBtn` on the page header:
   ```vue
   <LearnMoreHelpBtn guide-id="shop_order" tab="workflows" />
   ```
   Import from `src/modules/help/components/LearnMoreHelpBtn.vue`
3. **Do not** change `ModuleHelpDrawer`, `WorkspaceShell`, or help routes unless `routeMatchers` cannot cover the page path.

## 4. Writing & Visual Rules

- **End-user language only** (Admin / Merchant / Investor voice).
- **No RPC names**, table names, migration IDs, or ledger internals.
- **Steps must match real UI labels** on the attached page.
- **Role-appropriate**: merchants never get remittance/admin payout instructions; investors never get dropship ops.
- **FAQs = blockers** (“Why is Remit disabled?”), not essays.
- **Prefer 3–7 workflow steps**, 3–8 terms, 3–8 FAQs per guide.
- **Avoid empty tabs**: if a section has nothing useful, omit items or write one honest placeholder only for stubs.
- **Modern UI & Aesthetic Standards**:
  - Keep cards lightweight with `--bw-theme-border` borders and smooth `.card-hover` lift effects.
  - Use primary badge accents (`bg-primary-soft`) for step markers and icon wrappers.
  - Present workflows using numbered step badges and FAQs as expandable accordions (`<q-expansion-item>`).
- **Translation & i18n Support**:
  - UI labels (tabs, buttons, search placeholders) use `vue-i18n` translation keys defined in `src/i18n/en-US` and `src/i18n/bn`.
  - Include locale switcher (`currentLocale`) support on both Help Center portal and contextual Module Guide drawer.

## 5. Registry shape (reference)

```ts
{
  id: 'shop_order',
  title: 'Shop & Orders',
  caption: 'Orders, dropship, and settlements',
  icon: 'ph ph-storefront',
  scopes: ['app', 'shop'],
  audiences: ['admin', 'staff'], // or ['merchant'] for shop-facing guide
  routeMatchers: ['/app/shop/dropship', '/app/shop/orders'],
  overview: '...',
  workflows: [{ id: 'remittance', title: '...', steps: ['...'] }],
  terms: [{ term: '...', definition: '...' }],
  faqs: [{ question: '...', answer: '...' }],
}
```

`routeMatchers` are path substrings. Include the path segment(s) for the attached page so `?` auto-opens this guide.

## 6. Checklist before finishing

- [ ] `routeMatchers` cover the attached page URL path
- [ ] `scopes` / `audiences` match who should see the guide
- [ ] Searchable words appear in title/caption/overview/faqs
- [ ] Deep link works: `?module=<id>&section=workflows|terms|faqs`
- [ ] Optional `LearnMoreHelpBtn` only if the page header benefits from an inline entry
- [ ] Both English and Bengali translation keys are verified for UI elements
- [ ] Visual styling follows Quasar design tokens (`bg-primary-soft`, `soft-input`, border radii)

## 7. Example prompts

```
Using docs/OPTIMIZE_HELP_CENTER.md and @DropshipFinanceHubPage.vue,
add staff (app) help for courier remittance. Guide id: shop_order_remittance.
```

```
Using docs/OPTIMIZE_HELP_CENTER.md and @MerchantWalletPage.vue,
add merchant (shop) help for pending balance. Guide id: shop_merchant_wallet.
Add a Learn more button on the page header.
```
