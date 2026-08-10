# API: `thrift_customers`

Direct PostgREST under tenant RLS. Prefer upsert inside `create_thrift_sales_invoice`.

Schema: [../schema.md](../schema.md).

Unique `(tenant_id, phone_normalized)` on **primary** phone. Sale without phone does not create a customer.

| Field | Notes |
| :--- | :--- |
| `secondary_phone` | Optional alternate; not unique |
| `address` | Freeform street line |
| `address_parts` | JSONB `{ district, thana, post_code }` from BD static catalogs (same files as dropship) |
