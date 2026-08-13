# Procurement & Stock — Open Architecture Issues

**Module:** `procurement_stock`  
**Architecture (locked):** [v2/shipment](./v2/shipment/) · [v2/stock](./v2/stock/) · [v2/wallet](./v2/wallet/)  
**Updated:** 2026-08-13

Sell model, assign, ATP, listing FK, availability, and soft-allocation retirement are **decided** in the v2 docs — not listed here.

---

## 1. Warehouse ops after receive — deferred

No first-class **movement documents** that change `global_stocks.quantity` after receive.

| Gap | Meaning |
| :--- | :--- |
| Availability transfer / adjustment | sellable ↔ held / unsellable; write-off; cycle count |
| Return inbound | Return doc → qty onto a stock row (usually `held`) |
| Partial receive | Cost share when only part of the batch arrives |
| Receive rollback | Clean reverse of posted stock + stamps |
| Weight audit | History when package weights / cost inputs change |
| Transfer / multi-location | Later if single warehouse |

**Rule when built:** stock table = balances only; ops = docs that update balances. Not required before assign + ATP cutover.

---

## 2. Cost revision RPC detail

Revision path is locked in concept (recompute → re-stamp item; invoice snapshots frozen).

**Still open:** exact RPC contract, who may revise, optional wallet delta posts after sales.

---

## 3. Wallet posts on finalize / revision

Money ≠ shipment status (locked).

**Still open:** which wallet posts are day-one required vs stub-optional when payee/source is null.
