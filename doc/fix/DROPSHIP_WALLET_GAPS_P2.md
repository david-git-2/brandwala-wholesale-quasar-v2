# Dropship Wallet / Return — P2 Gaps & Implementation

**Priority:** P2 — operational edge-case correctness  
**Prerequisite:** P0 + P1 done  
**Drop:** [LEGACY_DROP](./DROPSHIP_WALLET_LEGACY_DROP.md) R5 (prepaid remittance CTA)  
**Index:** [README_DROPSHIP_WALLET.md](./README_DROPSHIP_WALLET.md)  
**Execute:** one agent session; files listed below only; stop at review gate.  
**Follow:** [docs/AI_WORKFLOW_SOP.md](../../docs/AI_WORKFLOW_SOP.md), [docs/PAGE_LAYOUT_AND_LOADERS.md](../../docs/PAGE_LAYOUT_AND_LOADERS.md), [docs/UI_CONSISTENCY.md](../../docs/UI_CONSISTENCY.md), [docs/COMPONENT_MODULARIZATION_GUIDE.md](../../docs/COMPONENT_MODULARIZATION_GUIDE.md), [docs/TANSTACK_QUERY_GUIDE.md](../../docs/TANSTACK_QUERY_GUIDE.md), [docs/ERROR_AND_SUCCESS_MESSAGE_GUIDE.md](../../docs/ERROR_AND_SUCCESS_MESSAGE_GUIDE.md)

---

## Gaps

### 1. Prepaid collection mode can conflict with recipient remittance action
- Dropship invoice may be `collection_source='billing_profile'`, but recipient remittance RPC enforces recipient collection.
- Impact: dead-end flows if UI still offers recipient remittance for prepaid orders.
- What this means in simple terms: Staff may be shown an action that cannot work for that order type.
- Related: `supabase/migrations/20261118000008_fix_payout_ledger_balance_after_select_into.sql`, `supabase/migrations/20261118000009_dropship_ledger_settlement_wireup.sql`

### 2. Remittance amount validation is lower-bound only
- Positive check exists, but no strict upper bound against collectible/outstanding constraints.
- Impact: over-remittance can distort paid/outstanding lifecycle.
- What this means in simple terms: The system checks “more than zero” but not “too much,” so over-collection can be saved.
- Related: `supabase/migrations/20261118000009_dropship_ledger_settlement_wireup.sql`  
- **Note:** Upper bound is enforced in P0 RPC; UI must not allow submitting over-cap amounts.

### 3. Middleman payout handoff not visible as explicit order-level state
- Financial payout completion is tracked separately from order status.
- Impact: ops view can treat delivered/payment_received as fully closed even when merchant payout is pending.
- What this means in simple terms: Operations may think an order is fully done even though merchant payment is still pending.
- Related: `web/src/modules/shop_order/composables/useDropshipOrderActions.ts`, `web/src/modules/shop_order/repositories/dropshipFinanceRepository.ts`

### 4. Storefront unified pricing gap for same product across multiple shipments
- Listing model is allocation/stock-line oriented, so same product can appear with inconsistent customer prices depending on source allocation/shipment.
- Impact: customer trust issues, pricing inconsistency, and harder promotion control.
- What this means in simple terms: Customers can see different prices for what appears to be the same item.
- Related: `supabase/migrations/20261024000000_shop_order_p14_dropship_default_min_price.sql`, `doc/SHOP_ORDER.md`

### 5. Condition-segmented pricing not formalized for normal vs open-box vs damaged storefront offers
- Condition stock buckets exist in inventory semantics, but offer-level condition pricing policy is not consistently modeled for customer-facing listing behavior.
- Impact: damaged/open-box handling becomes ad-hoc and can leak wrong price/quality expectations.
- What this means in simple terms: Item quality types are not consistently priced, so buyers may get confusing quality/price combinations.
- Related: `supabase/migrations/20260428120000_inventory_module.sql`, `doc/SHOP_ORDER.md`

### 6. Gift-item policy gap (customer-group-specific gifts + cost ownership)
- Gift/complimentary lines are not formalized as a scoped policy engine by customer group with explicit cost-bearing rules.
- Impact: promo leakage, duplicate gift application, and unclear margin ownership between tenant and middleman.
- What this means in simple terms: Free gift rules are not strict enough, so giveaways and costs can get out of control.
- Related: `doc/SHOP_ORDER.md`, `supabase/migrations/20261108000000_separate_dropship_charges_configurations.sql`

### 7. Override audit trail is not mandatory for sensitive financial edits
- Return-fee overrides and gift-cost ownership decisions are not enforced with actor+reason snapshots in one contract.
- Impact: post-facto dispute handling becomes weak.
- What this means in simple terms: When someone changes a fee, the system may not clearly record who changed it and why.
- Related: `supabase/migrations/20261118000008_fix_payout_ledger_balance_after_select_into.sql`

---

## Implementation (Phase 3 — ops UI + offer/gift)

**Goal:** Operators can see payout settlement and complete returns with condition/fee override; storefront uses unified condition-scoped price; gift rules are customer-group scoped.

### Prerequisite schema (if missing — one migration first, then UI)
- Offer table keyed by `(shop_id, product_id, condition_bucket)` for customer-facing price; allocations remain qty/cost source only
- Gift program + rule + gift item mapping scoped by `customer_group_id` with priority, eligibility, cost ownership (`tenant`/`middleman`/split), idempotency `(order_id, rule_id)`
- Do not mix large schema + large UI in one unfocused run

### READ ONLY (do not edit)
- `docs/PAGE_LAYOUT_AND_LOADERS.md`
- `docs/UI_CONSISTENCY.md`
- `docs/COMPONENT_MODULARIZATION_GUIDE.md`
- `web/src/modules/shop_order/pages/DropshipOrderDetailPage.vue` (placement reference only)

### CHANGE (only these)
- `web/src/modules/shop_order/pages/DropshipOrderDetailPage.vue` — wire settlement badge + return CTA; keep as container; extract if >250 lines
- `web/src/modules/shop_order/components/DropshipOrderDialogs.vue` — return dialog: condition split, suggested vs actual fee, override reason required; hide recipient remittance when `collection_source='billing_profile'`
- `web/src/modules/shop_order/components/ShopOrdersTable.vue` — payout settlement column/badge (`unpaid` / `partial` / `paid`)
- **Add:**
  - `web/src/modules/shop_order/components/DropshipSettlementBadge.vue`
  - `web/src/modules/shop_order/components/DropshipReturnFinalizeDialog.vue` (if dialog grows)
  - `web/src/modules/shop_order/components/DropshipOrderDetailSkeleton.vue`
- Listing/offer admin: existing shop listings pricing surface only — condition bucket + unified offer price; no new nav modules
- Gift admin: minimal rule form scoped by `customer_group_id` on existing dropship merchants/settings surface only
- Data via TanStack `useQuery`/`useMutation` + P1 repositories; `q-skeleton` for initial load; `parseSupabaseError` on mutations

### DO NOT
- Change order status enum
- Refactor unrelated shop_order pages
- Put catalog data into Pinia
- Skip `parseSupabaseError` / success toast rules
- Expand into marketing/CMS features
- Inline skeletons in page SFCs

### Done when
Settlement visible; return dialog posts `finalize_dropship_return`; one price per `(shop, product, condition)`; gift rules customer-group scoped; **stop for review gate**.

---

## Verification checklist (P2)

- [ ] Recipient remittance CTA hidden when `collection_source = billing_profile`
- [ ] Remittance UI cannot submit above outstanding/collectible cap
- [ ] Settlement badge shows unpaid / partial / paid on desk + list
- [ ] Return dialog: condition split, suggested vs actual fee, override reason required when fee changed
- [ ] Return posts `finalize_dropship_return` with `p_return_ref`
- [ ] Detail page uses skeleton for initial load
- [ ] One customer-facing price per `(shop_id, product_id, condition_bucket)`
- [ ] Gift rule scoped by `customer_group_id`; duplicate `(order, rule)` blocked
- [ ] LEGACY_DROP R5 marked done
