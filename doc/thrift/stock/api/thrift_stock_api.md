# API: `thrift_stocks`

Direct PostgREST on `thrift_stocks` (tenant RLS). Prefer RPCs for multi-table writes.

Schema: [../schema.md](../schema.md) · Workflow: [../workflow.md](../workflow.md).

## Columns

| Field | Type | Description |
| :--- | :--- | :--- |
| `additional_charges_cost` | `number | null` |  |
| `barcode` | `string | null` |  |
| `box_id` | `number | null` |  |
| `brand_name` | `string | null` |  |
| `category_id` | `number | null` |  |
| `color` | `string | null` |  |
| `condition` | `Database["public"]["Enums"]["thrift_condition"] | null` |  |
| `created_at` | `string` |  |
| `extra_origin_unit_price` | `number | null` |  |
| `extra_weight` | `number | null` |  |
| `held_at` | `string | null` |  |
| `held_by` | `string | null` |  |
| `held_for_name` | `string | null` |  |
| `held_for_phone` | `string | null` |  |
| `held_for_phone_normalized` | `string | null` |  |
| `hold_expires_at` | `string | null` |  |
| `hold_note` | `string | null` |  |
| `id` | `number` |  |
| `inserted_by` | `string` |  |
| `name` | `string | null` |  |
| `note` | `string | null` |  |
| `origin_unit_price` | `number | null` |  |
| `product_weight` | `number | null` |  |
| `quantity` | `number` |  |
| `section` | `Database["public"]["Enums"]["thrift_section"] | null` |  |
| `shelf_id` | `number | null` |  |
| `shipment_id` | `number` |  |
| `size` | `string | null` |  |
| `status` | `Database["public"]["Enums"]["thrift_stock_status"]` |  |
| `stock_type` | `Database["public"]["Enums"]["thrift_stock_type"]` |  |
| `tenant_id` | `number` |  |
| `type_id` | `number | null` |  |
| `updated_at` | `string` |  |
