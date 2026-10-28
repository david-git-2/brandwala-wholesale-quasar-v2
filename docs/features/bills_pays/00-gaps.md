# Bills & pays — gaps

What is **not finished** yet vs the money kernel target. Full product scope: [spec.md](spec.md). Build order for engineers: [kernel plan](../../../doc/fix/2026-10-12-bills-pays-kernel-plan.md).

**Status:** `not_built` = missing · `partial` = started · `design` = naming/copy only.

---

## Spine (core money rules — finish these before new pay/bill writers)

_No open BP25 items — duplicate POST with the same `idempotency_key` per books tenant returns the existing pay ([`post_money_in` / `post_money_out`](../../supabase/schemas/bills_pays/05_money_spine.sql))._

---

## Bills, notes, and adapters

_No open items — BP5 returns, BP8 desk notes, BP9 upsert adapters, BP10 kernel list reads, and BP23 bill summaries view are shipped ([tests.md](tests.md))._

---

## Shipment and adapters

_No open WA15 items — shipment AP sync uses `source_key` per bucket (and `bucket:CCY` when mixed); see [procurement money-kernel wiring](../procurement_stock/money-kernel-wiring.md)._

---

## Pay, leftover, and fixes

_No open BP11/BP12/WA13 items — profile **custody** apply, collect-time open credit/leftover, settlements-aware **`reverse_pay`**, and cheque bounce (whole pay v1) are shipped ([tests.md](tests.md) §H, §L)._

---

## Cashbook (till, safe, FX)

_No open BP15/BP16/BP21 items — customer collect requires **cash point + pot**, ledger lines use frozen FX on pots, and **`cashbook_accounts.account_class`** tags tenant asset vs profile custody ([tests.md](tests.md) §M)._

---

## Later cleanup

_No open BP17/BP24/BP2 items — commission pay out uses `post_money_out` ([tests.md](tests.md) §N); wholesale stock uses `commit_wholesale_bill_stock` before kernel issue + `line_meta.stock_ref` ([tests.md](tests.md) §O); app URL **`/app/cashbook`** with `/app/wallet` redirects (grant key `universal_wallet` unchanged)._
