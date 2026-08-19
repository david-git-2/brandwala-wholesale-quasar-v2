# PC Excel catalog import

UK Price Check spreadsheet → JSON → `products`. Run with `pnpm run pc:uploader` or `pnpm run python:pc`.

Catalog scope is warehouse **parent tenant id** (`products.parent_tenant_id`). Who ran the sync is stored as `inserted_by_tenant_id` (same as parent unless `--tenant-id` is passed).

## Required headers

Header row must include every name below (case and punctuation can differ). Empty columns between them are fine.

| Excel header | `products` column | Notes |
|---|---|---|
| AVAILABLE UNITS | `available_units` | Integer stock count |
| INNER CASE | `minimum_order_quantity` | Case size / MOQ. Always this column. |
| DESCRIPTION | `name` | Must have a value |
| PRODUCT CODE | `product_code` | Must have a value |
| EXPIRY DATE | `expire_date` | |
| PIECE PRICE £ | `list_price_amount` | GBP via `list_price_currency_id` |
| BARCODE | `barcode` | Match key with product code |
| COUNTRY OF ORIGIN | `country_of_origin` | |
| LANGUAGES | `languages` | |
| BATCH CODE / MANUFACTURE DATE | `batch_code_manufacture_date` | |
| IMAGE | `image_url` | Embedded pictures under this header (always this column) |
| BRAND | `brand` | Also `product_brands` if new |
| HAZARDOUS | `hazardous` | YES / Y / TRUE / 1 → row dropped |
| CATEGORY | `category` | Also `product_categories` if new |

All listed headers must exist. Per row, only **DESCRIPTION** and **PRODUCT CODE** must have a value. Rows with HAZARDOUS = yes are dropped. Other cells may be blank. Sync still needs a barcode to insert or match a product.

## Not from Excel

| Source | `products` column |
|---|---|
| Parent tenant id (default **15**) | `parent_tenant_id`, `inserted_by_tenant_id` |
| Vendor `PC` | `vendor_id`, `vendor_code` |
| Market `GB` | `market_code` |
| Always `excel` | `source` |

`tariff_code` is not stored.

## Commands

- UI: `pnpm run pc:uploader` — header row and parent tenant (default 15). IMAGE and INNER CASE are fixed.
- CLI: `pnpm run python:pc` — parent tenant defaults to 15; no image or case-size prompts.
