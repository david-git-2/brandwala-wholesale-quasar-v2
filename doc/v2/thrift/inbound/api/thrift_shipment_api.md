# API: `thrift_shipments`

Direct PostgREST on `thrift_shipments` (tenant RLS). Prefer RPCs for multi-table writes.

Schema: [../schema.md](../schema.md) · Workflow: [../workflow.md](../workflow.md).

## Columns

| Field | Type | Description |
| :--- | :--- | :--- |
| `cargo_conversion_rate` | `number | null` |  |
| `cargo_rate` | `number | null` |  |
| `cost_currency_id` | `number` |  |
| `created_at` | `string` |  |
| `default_markup_rate` | `number | null` |  |
| `id` | `number` |  |
| `inserted_by` | `string` |  |
| `labor_total_cost` | `number | null` |  |
| `marketing_tag_config` | `Json` |  |
| `name` | `string` |  |
| `product_conversion_rate` | `number | null` |  |
| `purchase_currency_id` | `number` |  |
| `tenant_id` | `number` |  |
| `total_cargo_weight_kg` | `number | null` |  |
| `transportation_total_cost` | `number | null` |  |
| `updated_at` | `string` |  |
| `washing_total_cost` | `number | null` |  |
