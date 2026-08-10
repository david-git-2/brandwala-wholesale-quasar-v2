# API: `thrift_accounting_ledger`

Direct PostgREST read (tenant RLS). Multi-table money writes go through sales/ops RPCs.

Schema: [../schema.md](../schema.md) · Workflow: [../workflow.md](../workflow.md).

## Columns

| Field | Type | Description |
| :--- | :--- | :--- |
| `id` | number | |
| `tenant_id` | number | |
| `date` | string | |
| `type` | `REVENUE` \| `EXPENSE` \| `REFUND` \| `LOSS` | |
| `source` | `INVOICE` \| `SHIPMENT` \| `OPERATIONAL` | |
| `reference_id` | number | Invoice id when source invoice |
| `amount` | number | `>= 0` |
| `note` | string \| null | Convention tags: `item_revenue`, `shop_delivery`, `rto_delivery_loss`, `return_courier`, … |
| `inserted_by` | string | |
| `created_at` | string | |
| `updated_at` | string | |

## Rules

- RTO / customer return: **insert** refund/loss — **never delete** prior expenses.  
- COD remittance: no row.  
- Staff mistake: delete invoice-sourced rows.  
- Not used for COGS or shipment allocation (see `thrift_sales_pnl_lines`).
