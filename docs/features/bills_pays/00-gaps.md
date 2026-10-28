# Bills & pays — gaps

What is **not finished** yet vs the money kernel target. Full product scope: [spec.md](spec.md). Build order for engineers: [kernel plan](../../../doc/fix/2026-10-12-bills-pays-kernel-plan.md).

**Status:** `not_built` = missing · `partial` = started · `design` = naming/copy only.

When you ship a row, delete it or strike through like [shop_order/00-gaps.md](../shop_order/00-gaps.md).

---

## Shipped (kernel track)

These initiatives are **live in prod** (migrations through `20261101120000_phase3_cashbook_edges`, backend **1.0.28**). pgTAP + golden: [tests.md](tests.md). Local/CI also applies `20261102120000_phase4_post_customer_receipt_signature.sql` when pushed.

| Area | IDs | Assert in tests |
| :--- | :--- | :--- |
| Spine | BP20, BP18 dual-write, BP25, BP22, BP19 (txn face) | Tier 1 rows in [tests.md](tests.md); BP18 audit [08 §1b](../../kernel/08-AUDIT-RECONCILIATION-AND-RUNBOOK.md) |
| Bills / reads | BP5, BP8, BP9, BP10, BP23 | §K, §I, §J |
| Shipment AP | WA15 | [procurement money-kernel wiring](../procurement_stock/money-kernel-wiring.md) |
| Pay / reverse | BP11, BP12, WA13 | §H, §L — whole + partial cheque bounce |
| Cashbook | BP15, BP16, BP21, **BP15‑t** | §M — collect + **point transfer** |
| Later cleanup | BP17, BP24, BP2 | §N, §O — `/app/cashbook`, `post_money_out` commission, `commit_wholesale_bill_stock` |
| Phase 1 finish | BP24‑r, BP17‑r, BP16‑r | §P — no `dispense_*`, `commit_sales_bill_stock`, drop `bill_lines.global_stock_id`, pot on void/refund legs |
| BP18‑c cutover | BP18‑c | [`bills_pays_bp18_settlements.sql`](../../../supabase/tests/bills_pays_bp18_settlements.sql) — settlements-first writers, mirror `pay_allocations`, readers on `bill_settlements` |
| Phase 3 edges | BP15‑t, WA13‑p | §M point transfer; §L split-tender cheque bounce |
| Phase 4 golden | **T‑golden** (kernel) | `golden_bills_pays_*`, `tier1_bills_pays_invariants.sql`, `backend:test` in CI |
| **T‑golden‑A/B** | dropship remittance + shipment AP FX | `golden_bills_pays_a_dropship_remittance.sql`, `golden_bills_pays_b_shipment_ap_fx.sql`, `001_cross_module_golden_helpers.sql` |
| Phase 5 decision | **BP3** | **Profile-only** — `customer_groups` are not money parties; bills/pays use `profiles` only ([spec](spec.md)) |

---

## Open gaps — by phase

Ship **in order** unless noted.

**T-golden-A/B follow-up:** None.

### Phase 5 — Naming and money parties (cross-module)

**Goal:** Product language and grants match “cashbook” (**BP2‑r** only).

| ID | Status | In plain words |
| :--- | :--- | :--- |
| **BP2‑r** | partial | Rename **`universal_wallet`** grant, **`list_wallet_*`** RPCs (bootstrap migration). Routes already **`/app/cashbook`**. |

**Out:** No “wallet” in user-facing module keys. ~~**BP3**~~ — **closed:** stay **profile-only**; no group-level money party.

---

## Phase map (one screen)

```text
Phase 5  BP2-r                         cashbook rename (grants/RPCs)
```

**One big release?** Phase **5** is grants/bootstrap — keep separate unless you want a wide change in the same week.
