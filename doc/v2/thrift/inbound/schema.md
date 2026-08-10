# Thrift Inbound (shipment & boxes) — Schema

Part of [Thrift](../README.md). Index: [../schema.md](../schema.md).

Field types from `database.types.ts` (live DB).


## `thrift_shipments`

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


## `thrift_boxes`

| Field | Type | Description |
| :--- | :--- | :--- |
| `created_at` | `string` |  |
| `id` | `number` |  |
| `inserted_by` | `string` |  |
| `name` | `string` |  |
| `received_weight` | `number | null` |  |
| `shipment_id` | `number` |  |
| `tenant_id` | `number` |  |
| `updated_at` | `string` |  |
| `weight` | `number | null` |  |
