# Thrift Stock — Schema (goal)

Index: [../schema.md](../schema.md) · Workflow: [workflow.md](./workflow.md)

Stock owns inventory identity and costing inputs. Sales invoices store sell prices only and keep `stock_id` for reports — see [../sales/schema.md](../sales/schema.md).

---

## Soft delete (goal)

Do **not** hard-delete stock rows that must remain joinable from invoice lines.

| Field | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `deleted_at` | TIMESTAMPTZ | No | Null = active; set = archived (soft-deleted) |
| `deleted_by` | TEXT | No | Who archived |

Rules:

1. Desk / open inventory lists exclude `deleted_at IS NOT NULL`.  
2. Sale and margin reports still join invoice lines → stock (including soft-deleted).  
3. Prefer archive over hard delete for any stock ever sold (`SOLD` or referenced by an invoice line).  
4. Hard delete (if any) only when never sold and never on an invoice — rare cleanup; not the desk “delete” path.

---

## `thrift_stocks`

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


## `thrift_pricings`

| Field | Type | Description |
| :--- | :--- | :--- |
| `cost_of_goods_sold` | `number` |  |
| `created_at` | `string` |  |
| `extra_expense_cost` | `number` |  |
| `id` | `number` |  |
| `inserted_by` | `string` |  |
| `is_listed_price_manual` | `boolean | null` |  |
| `listed_unit_price` | `number` |  |
| `markup_rate_override` | `number | null` |  |
| `stock_id` | `number` |  |
| `target_price` | `number` |  |
| `updated_at` | `string` |  |


## `thrift_stock_images`

| Field | Type | Description |
| :--- | :--- | :--- |
| `created_at` | `string` |  |
| `drive_file_id` | `string | null` |  |
| `id` | `number` |  |
| `image_url` | `string` |  |
| `inserted_by` | `string` |  |
| `is_primary` | `boolean` |  |
| `stock_id` | `number` |  |
| `updated_at` | `string` |  |


## `thrift_stock_measurements`

| Field | Type | Description |
| :--- | :--- | :--- |
| `arm_circumference_in` | `number | null` |  |
| `bust_in` | `number | null` |  |
| `closure_type` | `string | null` |  |
| `created_at` | `string` |  |
| `dress_style` | `string | null` |  |
| `fabric_stretch` | `string | null` |  |
| `hem_width_in` | `number | null` |  |
| `hips_in` | `number | null` |  |
| `inserted_by` | `string` |  |
| `length_in` | `number | null` |  |
| `lining` | `boolean | null` |  |
| `measurement_notes` | `string | null` |  |
| `neck_opening_in` | `number | null` |  |
| `neckline` | `string | null` |  |
| `shoulder_width_in` | `number | null` |  |
| `sleeve_length_in` | `number | null` |  |
| `sleeve_type` | `string | null` |  |
| `stock_id` | `number` |  |
| `tenant_id` | `number` |  |
| `updated_at` | `string` |  |
| `waist_in` | `number | null` |  |
