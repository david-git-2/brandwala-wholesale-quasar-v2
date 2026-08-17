# API: `thrift_settings`

Direct PostgREST on `thrift_settings` (tenant RLS). Prefer RPCs for multi-table writes.

Schema: [../schema.md](../schema.md) · Workflow: [../workflow.md](../workflow.md).

## Columns

| Field | Type | Description |
| :--- | :--- | :--- |
| `created_at` | `string` |  |
| `default_origin_unit_price` | `number` |  |
| `hand_tag_unit_cost` | `number | null` |  |
| `hand_tag_unit_currency_id` | `number | null` |  |
| `marketing_tag_config` | `Json` |  |
| `return_window_days` | `number` |  |
| `sticker_unit_cost` | `number | null` |  |
| `sticker_unit_currency_id` | `number | null` |  |
| `tenant_id` | `number` |  |
| `updated_at` | `string` |  |
