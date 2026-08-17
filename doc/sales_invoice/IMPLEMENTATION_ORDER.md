# Sales Invoice — Implementation Order

Parent-owned invoice + child UI. One sale = one row. Wallet Pay is out of this track.

**Canon:** [invoice/schema.md](./invoice/schema.md) §0 · [invoice/workflow_flow.md](./invoice/workflow_flow.md) · [SALES_INVOICE.md](./SALES_INVOICE.md) D-SI2, D-SI23–25 · stock sell/return: [../procurement_stock/stock/workflow_flow.md](../procurement_stock/stock/workflow_flow.md) Stage 5

**Locked model**

```text
One sale = one row
tenant_id              = parent (books)
issued_by_tenant_id    = selling child (desk / print / profiles)
Child UI               = customer view of that row
Parent UI              = books view of that row
Post                   = take stock, no wallet
Pay                    = wallet later (out of this track)
```

Keep table name `global_invoices` until SI8. **No local DB.** After SQL: `pnpm run deploy:backend` (linked prod push + regen `database.types.ts`) and linked types into `supabase.ts`.

**Out of this track:** wallet Pay/refund wiring, thrift invoices, new charge engine, shop Process Order UX (only touch `create_dual_invoice_from_dropship_order` so it uses the new create RPC).

---

## Phases

| # | Focus | Outcome | Status |
|:-:|:---|:---|:---:|
| **SI1** | **Who sold it** | `issued_by_tenant_id` NOT NULL (backfill = `tenant_id`); line `assigned_child_tenant_id` NULL. Do not flip `tenant_id`. Do not drop `parent_tenant_id`. App still works. | ✅ Done |
| **SI2** | **Create as parent** | `create_global_invoice` writes parent `tenant_id` + child `issued_by`; profile check; dropship dual invoice | ✅ Done |
| **SI3** | **RLS + list** | Child `issued_by`; parent all. Sister cannot open sister invoices. | ✅ Done |
| **SI4** | **History under parent** | Flip historical `tenant_id` to parent; unique `invoice_no`; assigned_child backfill | ✅ Done |
| **SI5** | **Child desk UI** | List/create/detail/preview per PAGE_LAYOUT + table_list; brands by `issued_by` | ✅ Done |
| **SI6** | **Parent books UI** | Read-only list/detail; Sold by column; no create | ✅ Done |
| **SI7** | **Drop legacy** | Drop `parent_tenant_id`-as-owner and child-as-`tenant_id` filters | ✅ Done |
| **SI8** | **Rename** | `global_invoices*` → `sales_invoices*`; drop `create_global_invoice` | ✅ Done |

---

## Agent rule

Work **one row** (SI1 → SI8) per session. Read canon for that row; mark Done only after that phase’s audit commands pass. Do not start the next row in the same session.
