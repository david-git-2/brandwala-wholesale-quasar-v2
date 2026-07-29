# UX_P3 — Dropship shop readiness checklist (impl only)

**Parent:** [IMPLEMENTATION_ORDER.md](./IMPLEMENTATION_ORDER.md) step 3  
**Session:** this file only + listed READ ONLY  
**Prerequisite:** UX_P2 green  
**Reuse later:** readiness RPC pattern per shop_type — **this phase only `dropship`**

---

### Goal
After creating/editing a dropship shop, admin sees a checklist of go-live deps. Not ready → clear next links. Ready → can invite / use storefront confidently.

### RPCs
**NEW** — one migration:

`supabase/migrations/YYYYMMDDHHMMSS_dropship_ux_shop_readiness.sql`

```text
get_dropship_shop_readiness(p_shop_id bigint)
returns table (
  shop_id bigint,
  has_access_group_with_price boolean,  -- group access with can_set_dropship_price
  has_customer_group_with_members boolean,
  has_billing_profile_linked boolean,   -- resolve_billing_profile_for_customer_group for ≥1 group on shop
  has_listing_with_floor boolean,       -- listing + min_dropship_price set
  has_active_courier boolean,           -- tenant courier usable for dropship
  ready boolean                         -- AND of above
)
```

- `security definer` or membership-checked like other shop admin RPCs
- Grant `authenticated`
- Idempotent create or replace

### READ ONLY
- `web/src/modules/shop_order/pages/ShopsPage.vue`
- `web/src/modules/shop_order/components/ShopFormDialog.vue` — dropship branch only as reference
- Existing helpers: `resolve_billing_profile_for_customer_group`, shop access matrix tables
- `docs/TANSTACK_QUERY_GUIDE.md`, `docs/PAGE_LAYOUT_AND_LOADERS.md`, `docs/UI_CONSISTENCY.md`

### CHANGE
- New migration (path above)
- `web/src/modules/shop_order/repositories/` — add method `getDropshipShopReadiness(shopId)` (new small file or existing shop admin repo)
- `web/src/modules/shop_order/services/shopOrderQueryKeys.ts` — key for readiness(shopId)
- **Add** `web/src/modules/shop_order/components/DropshipShopReadinessCard.vue`
  - Lists 5 checks + Ready/Not ready
  - Each fail row: link to existing route (access matrix, customer-groups, listings, couriers, billing profiles)
- Wire card on dropship shop context:
  - Prefer: after save on ShopsPage when `shop_type === 'dropship'`, or shop detail/pricing entry — **one** visible place only (ShopsPage expand/drawer or post-create panel)
- Run `npm run backend:types` (or project equivalent) so `web/src/types/supabase.ts` includes RPC

### DO NOT
- Build multi-step wizard that embeds all setup forms
- Add readiness for fixed_price / vendor_catalog
- Block DB shop insert if not ready (soft UX gate only)
- Edit wallet migrations

### Done checklist
- [ ] RPC returns five flags + `ready`
- [ ] Card shows on dropship shop admin surface
- [ ] Failed rows deep-link to correct admin pages
- [ ] Types regenerated
- [ ] Non-dropship shops unchanged
