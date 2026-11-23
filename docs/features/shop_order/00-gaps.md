# Shop order & dropship — gaps

Open with [spec.md](spec.md). Types: `not_built` | `doc_wrong` | `sql_split`. When you ship a row: delete it.

| ID | Type | Plan / doc | Code today | Fix |
| :--- | :--- | :--- | :--- | :--- |
| SO1 | ~~not_built~~ | Declarative `shop_order/03_rpcs.sql` matched live remittance + payload | ~~Truncated remittance RPCs~~ | **Done (2026-09)** |
| SO2 | ~~design~~ | Bank transfer credits wallet from remittance remainder only | ~~`transfer_dropship_reseller_profit` after remittance~~ | **Done (2026-09)** |
| SO3 | ~~not_built~~ | Finance hub delivered costing = fields only (WA5) | ~~`confirm_dropship_delivered_costing` credited courier COD~~ | **Done (2026-09)** |
| SO4 | ~~not_built~~ | Courier wallet = COD receivable at deliver; tenant cash at remittance | ~~Remittance debited courier with no prior credit~~ | **Done (2026-09)** |
| SO5 | ~~not_built~~ | Remittance closes settlement | ~~Skipped settlement~~ | **Done (2026-09)** |
| SO6 | ~~design~~ | Catalog pack → Delivery paper close | ~~`fulfill_shop_order_to_invoice` for fixed_price~~ | **Done (2026-10):** RPC blocks `fixed_price`; use Delivery paper close |
| SO7 | ~~not_built~~ | US-4 recipient call | ~~No call gate~~ | **Done (2026-10)** |
| SO-DR1 | ~~not_built~~ | Pre-confirm status at place | ~~Place always → `confirmed` when requests exist~~ | **Done:** enum + `submit_dropship_order_from_cart` / `staff_submit_*` branch (`20261123210000_*`) |
| SO-DR2 | ~~not_built~~ | Staff review RPC + app UI | ~~No approve/deny~~ | **Done:** `finalize_dropship_resell_discount_review` + `DropshipResellDiscountReviewPanel` on staff order detail (`20261123230000_*`) |
| SO-DR3 | ~~not_built~~ | Shop messaging + status strip | ~~Request on detail only~~ | **Done:** toast, strip, labels (`customerOrderStatusUi`, `CustomerOrderDetailPage`) |
| SO-DR4 | design | COD/totals at place vs after approve | TBD | Document + implement: listed resell until approve (recommended) |
| SO-CA1 | partial | [dropship-courier-ar-redesign.md](dropship-courier-ar-redesign.md) — option **B** | **Ship (done):** draft customer AR + payout note + draft courier AR (`upsert_dropship_courier_ar_bill`). **Open:** issue before remit; remittance closes courier AR + auto customer AR; retire AP retention; golden remittance tests |
