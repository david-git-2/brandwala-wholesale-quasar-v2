# UX_P5 — Merchant money page (impl only)

**Parent:** [IMPLEMENTATION_ORDER.md](./IMPLEMENTATION_ORDER.md) step 5  
**Session:** this file only + listed READ ONLY  
**Prerequisite:** UX_P4 green; UWL + middleman entity from wallet pack  
**Reuse later:** actor-scoped wallet summary page pattern — **shop customer scope only now**

---

### Goal
Dropship merchant (shop login) sees own available / pending / locked balance and ledger lines with order refs and deduction reasons. Admin Merchants/Hub unchanged as write path.

### RPCs
**NEW** — one migration:

`supabase/migrations/YYYYMMDDHHMMSS_dropship_ux_merchant_wallet_shop_scope.sql`

```text
get_my_dropship_wallet_summary()
returns table (
  billing_profile_id bigint,
  available_balance numeric,
  pending_balance numeric,
  locked_balance numeric,
  currency text
)

list_my_dropship_wallet_ledger(
  p_limit int default 50,
  p_offset int default 0
)
returns table (
  id bigint,
  created_at timestamptz,
  transaction_type text,
  amount numeric,
  balance_after numeric,
  source_id text,
  order_id bigint,          -- null if not resolvable
  note text
)
```

Rules:
- Resolve caller via `customer_group_members` → billing profile (`resolve_billing_profile_for_customer_group`)
- Read UWL for that `entity_id` / `entity_type` in (`middleman`, compat `customer` if wallet pack still dual)
- **No** write/dispense from these RPCs
- Reject if no billing profile linked (clear error message)
- Grant `authenticated`; enforce tenant + membership in function body

### READ ONLY
- `web/src/modules/shop_order/pages/DropshipMerchantsPage.vue` — admin balance UX as label reference only
- `web/src/modules/shop_order/repositories/dropshipFinanceRepository.ts` — admin UWL read patterns
- `web/src/modules/shop_order/routes/shopRoutes.ts`
- `web/src/modules/shop_order/pages/CustomerOrdersPage.vue`, `CustomerOrderDetailPage.vue`
- `doc/wallet/UNIVERSAL_WALLET_LEDGER.md` or existing UWL migration — entity types only
- `docs/TANSTACK_QUERY_GUIDE.md`, `docs/PAGE_LAYOUT_AND_LOADERS.md`, `docs/UI_CONSISTENCY.md`, `docs/ERROR_AND_SUCCESS_MESSAGE_GUIDE.md`

### CHANGE
- New migration (path above)
- **Add** `web/src/modules/shop_order/repositories/merchantWalletRepository.ts`
- **Add** composable `useMerchantWalletQuery.ts` (TanStack)
- Extend `shopOrderQueryKeys.ts`
- **Add** `web/src/modules/shop_order/pages/MerchantWalletPage.vue` (shop scope)
- Register route in `shopRoutes.ts` (name e.g. `shop-merchant-wallet-page`; guard `shop_storefront` or existing shop order module — match peer customer pages)
- Link from `CustomerOrdersPage.vue` header/actions and optionally `CustomerOrderDetailPage.vue`
- Copy: **Merchant wallet** / Available / Pending / Locked; no admin “Dispense” button
- Run types regen

### DO NOT
- Let shop users call admin dispense / remittance RPCs
- Build payout request workflow (read-only v1)
- Expose other merchants’ balances
- Port Thrift wallet UI patterns wholesale
- Change Finance Hub writes

### Done checklist
- [ ] Summary RPC returns balances for linked billing profile only
- [ ] Ledger RPC paginates; includes order ref when possible
- [ ] Shop route page loads with skeleton per layout guide
- [ ] Link from customer orders
- [ ] Types regenerated
- [ ] Admin Merchants page still the dispense entry (hub)
