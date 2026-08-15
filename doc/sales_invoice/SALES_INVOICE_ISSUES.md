# Sales & Invoice — Open Architecture Issues

**Module:** `sales_invoice`  
**Architecture (locked):** [invoice/](./invoice/) · [../procurement_stock/stock/](../procurement_stock/stock/) · [../procurement_stock/shipment/](../procurement_stock/shipment/) · [../wallet/](../wallet/)  
**Updated:** 2026-08-15

Scope: desk sales only. Thrift (`thrift_sales_invoices`) out of scope.

**Decided in v2 (not listed as open):** one invoice pack for wholesale / retail / dropship; flexible charges; required `shipment_item_id`; provisional COGS frozen at post; actual P&L via report join; customer face = print layer; draft holds = query draft lines; post stub-skips wallet AR; Pay uses `source_type = 'sales_invoice'` (+ `sales_invoice_return` for refunds); **return stock = `return_inbound` movement** (default `held` @ returns; staff set grade + availability).

---

## 1. Cutover table names

**Solution locked:** Target family `sales_invoices*` — [schema.md](./invoice/schema.md).

**Still open:** migration path from live `global_invoices*` (rename vs drop-recreate); RPC/UI string updates.

---

## 2. Post / void / return / pay RPC detail

**Solution locked:** [workflow_flow.md](./invoice/workflow_flow.md); wallet keys in [invoice schema §5.2](./invoice/schema.md) · [wallet schema](../wallet/UNIVERSAL_WALLET_LEDGER.md).

**Still open:** exact RPC names / args / return shapes; module actions.

| Gap | Meaning | In first invoice cut? |
| :--- | :--- | :---: |
| RPC set | create / item CRUD / post / void / return / pay / fulfillment | Yes |
| Post ATP | Sellable only; include other drafts + shop carts | Yes |
| Return stock path | Posted `return_inbound` movement (default `held` @ returns; grade + availability on the movement) — [stock/workflow_flow.md](../procurement_stock/stock/workflow_flow.md) Stage 5 · procurement **W9** | **Locked** — build with W9 |

---

## 3. Treasury payment tables vs wallet-only

**Solution locked:** Wallet ledger is the money movement truth for Pay; invoice AR fields update in the same Pay RPC.

**Still open:** whether `global_payments` / `invoice_payments` remain as allocation UX tables beside wallet, or Pay writes wallet + invoice balances only. Not required to lock `source_type` (already locked).

---

## 4. Doc pack remaining

**Solution locked:** [schema.md](./invoice/schema.md) · [workflow_flow.md](./invoice/workflow_flow.md) · wallet Stage 2 desk-sales rule.

**Still open:** invoice API / per-RPC stub files under `doc/sales_invoice/invoice/` (optional before implement).
